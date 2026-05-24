;;; lzdockel-container.el --- Container list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'tabulated-list)

(defvar lzdockel-container-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `lzdockel-container-mode'.")

(define-derived-mode lzdockel-container-mode tabulated-list-mode "Lzdockel-Container"
  "Major mode for listing Docker containers."
  (setq tabulated-list-format
        [("ID" 14 t)
         ("Image" 20 t)
         ("Status" 20 t)
         ("Names" 20 t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header)
  (message "Buffer: %s" (buffer-name)))

(provide 'lzdockel-container)
;;; lzdockel-container.el ends here
