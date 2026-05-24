;;; lzdockel-container.el --- Container list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'tabulated-list)
(require 'lzdockel-core)
(require 'lzdockel-faces)

(defvar lzdockel-container-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'lzdockel-container-refresh)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `lzdockel-container-mode'.")

(defun lzdockel-container--format-status (status)
  "Apply face to STATUS string based on its content."
  (cond
   ((string-prefix-p "Up" status)
    (propertize status 'face 'lzdockel-status-running))
   ((string-prefix-p "Exited" status)
    (propertize status 'face 'lzdockel-status-exited))
   (t status)))

(defun lzdockel-container--build-entry (container)
  "Build a `tabulated-list-entries` entry from CONTAINER alist."
  (let ((id (cdr (assoc 'ID container)))
        (image (cdr (assoc 'Image container)))
        (status (cdr (assoc 'Status container)))
        (names (cdr (assoc 'Names container))))
    (list id (vector id
                     (or image "")
                     (lzdockel-container--format-status (or status ""))
                     (or names "")))))

(defun lzdockel-container-refresh ()
  "Refresh the container list from Docker."
  (interactive)
  (let* ((buf (current-buffer))
         (buf-name (buffer-name buf)))
    (lzdockel-core-run
     (lambda (output)
       (when (buffer-live-p buf)
         (with-current-buffer buf
           (when (string= (buffer-name) buf-name)
             (let ((containers (lzdockel-core-parse-json-lines output))
                   (entries '()))
               (dolist (container containers)
                 (push (lzdockel-container--build-entry container) entries))
               (setq tabulated-list-entries (nreverse entries))
               (tabulated-list-print))))))
     "container" "ls" "-a" "--format" "{{json .}}")))

(define-derived-mode lzdockel-container-mode tabulated-list-mode "Lzdockel-Container"
  "Major mode for listing Docker containers."
  (setq tabulated-list-format
        [("ID" 14 t)
         ("Image" 20 t)
         ("Status" 20 t)
         ("Names" 20 t)])
  (setq tabulated-list-padding 2)
  (setq tabulated-list-revert-hook #'lzdockel-container-refresh)
  (tabulated-list-init-header))

(provide 'lzdockel-container)
;;; lzdockel-container.el ends here
