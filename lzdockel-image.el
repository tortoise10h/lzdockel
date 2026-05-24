;;; lzdockel-image.el --- Image list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)

(defun lzdockel-image-list (callback)
  "Fetch Docker images asynchronously, calling CALLBACK with results.
CALLBACK receives a list of image alists."
  (lzdockel-core-run
   (lambda (output)
     (funcall callback (lzdockel-core-parse-json-lines output)))
   "image" "ls" "--format" "{{json .}}"))

(provide 'lzdockel-image)
;;; lzdockel-image.el ends here
