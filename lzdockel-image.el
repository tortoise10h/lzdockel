;;; lzdockel-image.el --- Image list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'tabulated-list)
(require 'lzdockel-core)
(require 'lzdockel-faces)

(defvar lzdockel-image-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'lzdockel-image-refresh)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `lzdockel-image-mode'.")

(defun lzdockel-image--build-entry (image)
  "Build a `tabulated-list-entries` entry from IMAGE alist."
  (let ((id (cdr (assoc 'ID image)))
        (repository (cdr (assoc 'Repository image)))
        (tag (cdr (assoc 'Tag image)))
        (size (cdr (assoc 'Size image)))
	(created-since (cdr (assoc 'CreatedSince image))))
    (list id (vector id
		     (or repository "")
		     (or tag "")
		     (or size "")
		     (or created-since "")
                     ))))

(defun lzdockel-image-refresh ()
  "Refresh the image list from Docker."
  (interactive)
  (let* ((buf (current-buffer))
         (buf-name (buffer-name buf)))
    (lzdockel-core-run
     (lambda (output)
       (when (buffer-live-p buf)
         (with-current-buffer buf
           (when (string= (buffer-name) buf-name)
             (let ((images (lzdockel-core-parse-json-lines output))
                   (entries '()))
               (dolist (image images)
                 (push (lzdockel-image--build-entry image) entries))
               (setq tabulated-list-entries (nreverse entries))
               (tabulated-list-print))))))
     "image" "ls" "--format" "{{json .}}")))

(define-derived-mode lzdockel-image-mode tabulated-list-mode "Lzdockel-Image"
  "Major mode for listing Docker images."
  (setq tabulated-list-format
        [
	 ("ID" 14 t)
	 ("Repository" 25 t)
         ("Tag" 15 t)
         ("Size" 12 t)
	 ("Created Since" 20 t)])
  (setq tabulated-list-padding 2)
  (setq tabulated-list-revert-hook #'lzdockel-image-refresh)
  (tabulated-list-init-header))

(provide 'lzdockel-image)
;;; lzdockel-image.el ends here
