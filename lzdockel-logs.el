;;; lzdockel-logs.el --- Container logs viewer for lzdockel  -*- lexical-binding: t; -*-

;;; Code:

(require 'ansi-color)
(require 'lzdockel-core)

(defvar lzdockel-logs-tail-lines 500
  "Number of historical log lines to fetch initially.")

(defvar-local lzdockel-logs--container-id nil
  "Docker container ID for the current logs buffer.")

(defvar-local lzdockel-logs--container-name nil
  "Docker container name for the current logs buffer.")

(defvar-local lzdockel-logs--running-p nil
  "Non-nil if the container was running when logs were opened.")

(defvar-local lzdockel-logs--process nil
  "Active `docker logs' process associated with the current logs buffer.")

(defun lzdockel-logs--cleanup ()
  "Terminate any active log-streaming process for the current buffer."
  (when (process-live-p lzdockel-logs--process)
    (delete-process lzdockel-logs--process))
  (setq lzdockel-logs--process nil))

(defun lzdockel-logs--command (container-id running-p)
  "Build the `docker logs' command list for CONTAINER-ID.
If RUNNING-P is non-nil, include `-f' to follow live output."
  (append '("docker" "logs" "--tail")
          (list (number-to-string lzdockel-logs-tail-lines))
          (when running-p '("-f"))
          (list container-id)))

(defun lzdockel-logs--append (buf text)
  "Append TEXT to logs buffer BUF, following output if point is at end."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (let ((inhibit-read-only t)
            (at-end-windows nil)
            (start nil))
        (dolist (w (get-buffer-window-list buf nil t))
          (when (= (window-point w) (point-max))
            (push w at-end-windows)))
        (save-excursion
          (goto-char (point-max))
          (setq start (point))
          (insert text)
          (ansi-color-apply-on-region start (point)))
        (dolist (w at-end-windows)
          (set-window-point w (point-max)))))))

(defun lzdockel-logs--start-process ()
  "Start or restart the `docker logs' process for the current logs buffer."
  (lzdockel-logs--cleanup)
  (let ((buf (current-buffer))
        (id lzdockel-logs--container-id)
        (running-p lzdockel-logs--running-p))
    (when (and id (not (string-empty-p id)))
      (let ((inhibit-read-only t))
        (erase-buffer))
      (let ((process-connection-type nil))
        (setq lzdockel-logs--process
              (make-process
               :name (format "lzdockel-logs-%s" id)
               :buffer nil
               :command (lzdockel-logs--command id running-p)
               :filter (lambda (_proc chunk)
                         (lzdockel-logs--append buf chunk))
               :sentinel (lambda (proc event)
                           (when (and (buffer-live-p buf)
                                      (not (process-live-p proc)))
                             (with-current-buffer buf
                               (when (eq lzdockel-logs--process proc)
                                 (setq lzdockel-logs--process nil)))
                             (let ((status (process-exit-status proc)))
                               (unless (or (zerop status)
                                           (string-match-p "killed\\|terminated" event))
                                 (lzdockel-logs--append
                                  buf
                                  (format "\n[lzdockel: docker logs exited with status %d]\n"
                                          status))))))))))))

(defun lzdockel-logs-refresh ()
  "Refresh logs in the current `lzdockel-logs-mode' buffer."
  (interactive)
  (when (derived-mode-p 'lzdockel-logs-mode)
    (lzdockel-logs--start-process)))

(defvar lzdockel-logs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'lzdockel-logs-refresh)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `lzdockel-logs-mode'.")

(define-derived-mode lzdockel-logs-mode special-mode "Lzdockel-Logs"
  "Major mode for viewing Docker container logs."
  (setq buffer-read-only t)
  (setq-local revert-buffer-function
              (lambda (_ignore-auto _noconfirm)
                (lzdockel-logs-refresh)))
  (add-hook 'kill-buffer-hook #'lzdockel-logs--cleanup nil t))

(defun lzdockel-logs-buffer-name (item)
  "Return the logs buffer name for container ITEM."
  (let ((name (lzdockel-core-get item 'Names))
        (id (lzdockel-core-get item 'ID)))
    (format "*lzdockel-logs: %s*"
            (if (string-empty-p name) id name))))

(defun lzdockel-logs-show (item)
  "Open a logs buffer for container ITEM and fetch or stream its logs."
  (let* ((id (lzdockel-core-get item 'ID))
         (name (lzdockel-core-get item 'Names))
         (status (lzdockel-core-get item 'Status))
         (running-p (string-prefix-p "Up" status))
         (buf (get-buffer-create (lzdockel-logs-buffer-name item))))
    (with-current-buffer buf
      (lzdockel-logs--cleanup)
      (unless (derived-mode-p 'lzdockel-logs-mode)
        (lzdockel-logs-mode))
      (setq lzdockel-logs--container-id (if (string-empty-p id) name id))
      (setq lzdockel-logs--container-name (if (string-empty-p name) id name))
      (setq lzdockel-logs--running-p running-p)
      (setq header-line-format
            (format " Container: %s (%s)"
                    lzdockel-logs--container-name
                    (if running-p "running, following" "stopped")))
      (lzdockel-logs--start-process))
    (pop-to-buffer buf)
    buf))

(provide 'lzdockel-logs)
;;; lzdockel-logs.el ends here
