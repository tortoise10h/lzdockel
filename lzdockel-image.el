;;; lzdockel-image.el --- Image list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)
(require 'lzdockel-inspect)
(require 'lzdockel-logs)

(defconst lzdockel-image-pull-log-buffer "*lzdockel-pull-log*"
  "Name of the buffer displaying live `docker pull' output.")

(defvar lzdockel-image--pull-process nil
  "Active `docker pull' process, if any.")

(define-derived-mode lzdockel-image-pull-log-mode special-mode "Lzdockel-Pull-Log"
  "Major mode for viewing live Docker image pull output."
  (setq buffer-read-only t))

(defun lzdockel-image-list (callback)
  "Fetch Docker images asynchronously, calling CALLBACK with results.
CALLBACK receives a list of image alists."
  (lzdockel-core-run
   (lambda (output)
     (funcall callback (lzdockel-core-parse-json-lines output)))
   "image" "ls" "--format" "{{json .}}"))

(defun lzdockel-image-delete (item callback)
  "Delete the image referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (lzdockel-core-action-run
   (format "Delete image %s:%s? "
           (lzdockel-core-get item 'Repository)
           (lzdockel-core-get item 'Tag))
   `("image" "rm" ,(lzdockel-core-get item 'ID))
   callback))

(defun lzdockel-image-inspect (item &optional _callback)
  "Open an inspect buffer for the image referenced by ITEM.
CALLBACK is accepted for `lzdockel-dashboard-dispatch-action'
compatibility and ignored."
  (lzdockel-inspect-show "image" item))

(defun lzdockel-image--prepare-pull-log-buffer (image)
  "Create or reset the pull log buffer for IMAGE and return it."
  (let ((buf (get-buffer-create lzdockel-image-pull-log-buffer)))
    (with-current-buffer buf
      (unless (derived-mode-p 'lzdockel-image-pull-log-mode)
        (lzdockel-image-pull-log-mode))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Pulling %s...\n\n" image)))
      (setq header-line-format (format " Pull: %s (in progress)" image)))
    buf))

(defun lzdockel-image--run-pull (image log-buf callback)
  "Run `docker pull' for IMAGE, streaming output to LOG-BUF.
CALLBACK is called with (SUCCESS-P EXIT-CODE OUTPUT) when finished."
  (let ((process-connection-type nil)
        (chunks nil))
    (setq lzdockel-image--pull-process
          (make-process
           :name (format "lzdockel-pull-%s" image)
           :buffer nil
           :command (list "docker" "pull" image)
           :filter (lambda (_proc chunk)
                     (push chunk chunks)
                     (lzdockel-logs--append log-buf chunk))
           :sentinel
           (lambda (proc _event)
             (when (memq (process-status proc) '(exit signal))
               (when (eq lzdockel-image--pull-process proc)
                 (setq lzdockel-image--pull-process nil))
               (let* ((exit-code (process-exit-status proc))
                      (success-p (and (eq (process-status proc) 'exit)
                                      (zerop exit-code)))
                      (output (string-trim
                               (apply #'concat (nreverse chunks)))))
                 (funcall callback success-p exit-code output))))))))

(defun lzdockel-image-pull (image &optional callback)
  "Pull Docker IMAGE asynchronously via `docker pull'.
Streams live output to `lzdockel-image-pull-log-buffer'.
CALLBACK is called with no arguments on success."
  (let ((trimmed (string-trim (or image ""))))
    (cond
     ((string-empty-p trimmed)
      (message "Image pull aborted: no image specified."))
     ((process-live-p lzdockel-image--pull-process)
      (message "An image pull is already in progress (press P to view log)."))
     (t
      (let ((log-buf (lzdockel-image--prepare-pull-log-buffer trimmed)))
        (message "Pulling image %s... (press P to view log)" trimmed)
        (lzdockel-image--run-pull
         trimmed log-buf
         (lambda (success-p exit-code output)
           (when (buffer-live-p log-buf)
             (with-current-buffer log-buf
               (setq header-line-format
                     (if success-p
                         (format " Pull: %s (completed)" trimmed)
                       (format " Pull: %s (failed, exit %d)" trimmed exit-code))))
             (lzdockel-logs--append
              log-buf
              (if success-p
                  "\n[lzdockel: pull completed successfully]\n"
                (format "\n[lzdockel: pull failed (exit %d)]\n" exit-code))))
           (if success-p
               (progn
                 (message "Pulled image %s" trimmed)
                 (when callback
                   (funcall callback)))
             (message "Failed to pull image %s: Command failed (exit %d): %s"
                      trimmed exit-code output)))))))))

(defun lzdockel-image-show-pull-log ()
  "Display the live Docker image pull log buffer if it exists."
  (let ((buf (get-buffer lzdockel-image-pull-log-buffer)))
    (if (buffer-live-p buf)
        (pop-to-buffer buf)
      (message "No pull log available; press p to pull an image."))))

(provide 'lzdockel-image)
;;; lzdockel-image.el ends here
