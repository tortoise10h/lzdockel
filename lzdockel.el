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

(defgroup lzdockel nil
  "Native Emacs interface for Docker management."
  :group 'tools
  :prefix "lzdockel-")

(require 'lzdockel-faces)
(require 'lzdockel-core)
(require 'lzdockel-container)
(require 'lzdockel-image)
(require 'lzdockel-volume)
(require 'lzdockel-network)
(require 'lzdockel-dashboard)

;;;###autoload
(defun lzdockel()
  "Open the lzdockel Docker management interface."
  (interactive)
  (lzdockel-dashboard))

(provide 'lzdockel)
;;; lzdockel.el ends here
