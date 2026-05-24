;;; lzdockel-container.el --- Container list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)

(defun lzdockel-container-list (callback)
  "Fetch Docker containers asynchronously, calling CALLBACK with results.
CALLBACK receives a list of container alists."
  (lzdockel-core-run
   (lambda (output)
     (funcall callback (lzdockel-core-parse-json-lines output)))
   "container" "ls" "-a" "--format" "{{json .}}"))

(provide 'lzdockel-container)
;;; lzdockel-container.el ends here
