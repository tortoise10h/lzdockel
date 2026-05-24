;;; lzdockel-image.el --- Image list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'tabulated-list)

(defvar lzdockel-image-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `lzdockel-image-mode'.")

(define-derived-mode lzdockel-image-mode tabulated-list-mode "Lzdockel-Image"
  "Major mode for listing Docker images."
  (setq tabulated-list-format
        [("Repository" 25 t)
         ("Tag" 15 t)
         ("ID" 14 t)
         ("Size" 12 t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header)
  (message "Buffer: %s" (buffer-name)))

(provide 'lzdockel-image)
;;; lzdockel-image.el ends here
