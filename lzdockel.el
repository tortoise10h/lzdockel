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

;;;###autoload
(defun lzdockel ()
  "Open the lzdockel Docker management interface."
  (interactive)
  (lzdockel-containers))

(provide 'lzdockel)
;;; lzdockel.el ends here
