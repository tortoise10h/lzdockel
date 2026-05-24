;;; lzdockel.el --- Native Emacs interface for Docker management  -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Lzdockel Contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: tools, docker
;; URL: https://github.com/yourusername/lzdockel

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Lzdockel provides a native Emacs interface for managing Docker containers
;; and images, inspired by lazydocker.
;;
;; Entry point: `M-x lzdockel`

;;; Code:

(require 'tabulated-list)

(defgroup lzdockel nil
  "Native Emacs interface for Docker management."
  :group 'tools
  :prefix "lzdockel-")

(require 'lzdockel-faces)
(require 'lzdockel-core)
(require 'lzdockel-container)
(require 'lzdockel-image)

;;;###autoload
(defun lzdockel-containers ()
  "List Docker containers."
  (interactive)
  (pop-to-buffer "*lzdockel-containers*")
  (lzdockel-container-mode)
  (tabulated-list-revert))

;;;###autoload
(defun lzdockel-images ()
  "List Docker images."
  (interactive)
  (pop-to-buffer "*lzdockel-images*")
  (lzdockel-image-mode)
  (tabulated-list-revert))

(defun lzdockel-menu--select-view (view-fn)
  "Select a view and close the menu window."
  (let ((main-window (get-buffer-window (current-buffer))))
    (when main-window
      (delete-window main-window))
    (funcall view-fn)))

(defvar lzdockel-menu-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "c") (lambda () (interactive) (lzdockel-menu--select-view #'lzdockel-containers)))
    (define-key map (kbd "i") (lambda () (interactive) (lzdockel-menu--select-view #'lzdockel-images)))
    (define-key map (kbd "q") (lambda () (interactive) (kill-buffer "*lzdockel*")))
    (define-key map (kbd "g") #'lzdockel-menu-refresh)
    map)
  "Keymap for `lzdockel-menu-mode'.")

(define-derived-mode lzdockel-menu-mode special-mode "Lzdockel"
  "Major mode for the lzdockel dashboard."
  (setq buffer-read-only t)
  (hl-line-mode 1))

(defun lzdockel-menu--render ()
  "Render the lzdockel menu buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (propertize "Lzdockel - Docker Management\n" 'face '(:weight bold :height 1.2)))
    (insert (make-string 40 ?=) "\n\n")
    (insert "Available commands:\n\n")
    (insert "  " (propertize "c" 'face 'font-lock-keyword-face) "  Containers\n")
    (insert "  " (propertize "i" 'face 'font-lock-keyword-face) "  Images\n")
    (insert "\n")
    (insert "  " (propertize "g" 'face 'font-lock-keyword-face) "  Refresh\n")
    (insert "  " (propertize "q" 'face 'font-lock-keyword-face) "  Quit\n")))

(defun lzdockel-menu-refresh ()
  "Refresh the lzdockel menu buffer."
  (interactive)
  (lzdockel-menu--render))

;;;###autoload
(defun lzdockel ()
  "Open the lzdockel Docker management interface."
  (interactive)
  (let ((menu-height (max 3 (/ (frame-height) 3))))
    (split-window-below (- menu-height))
    (other-window 1)
    (switch-to-buffer "*lzdockel*")
    (lzdockel-menu-mode)
    (lzdockel-menu--render)
    (goto-char (point-min))))

(provide 'lzdockel)
;;; lzdockel.el ends here
