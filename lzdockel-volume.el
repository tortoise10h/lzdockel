;;; lzdockel-volume.el --- Volume list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)

(defun lzdockel-volume-list (callback)
  "Fetch Docker volumes asynchronously, calling CALLBACK with results.
CALLBACK receives a list of volume alists."
  (lzdockel-core-run
   (lambda (output)
     (funcall callback (lzdockel-core-parse-json-lines output)))
   "volume" "ls" "--format" "{{json .}}"))

(provide 'lzdockel-volume)
;;; lzdockel-volume.el ends here
