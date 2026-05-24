;;; lzdockel-faces.el --- Face definitions for lzdockel  -*- lexical-binding: t; -*-

;;; Code:

(defgroup lzdockel-faces nil
  "Faces used by lzdockel."
  :group 'lzdockel
  :group 'faces
  :prefix "lzdockel-")

(defface lzdockel-status-running
  '((t :inherit success :weight bold))
  "Face for running container status.")

(defface lzdockel-status-exited
  '((t :inherit error))
  "Face for exited/errored container status.")

(defface lzdockel-image-id
  '((t :inherit font-lock-variable-use-face))
  "Face for Docker image IDs.")

(provide 'lzdockel-faces)
;;; lzdockel-faces.el ends here
