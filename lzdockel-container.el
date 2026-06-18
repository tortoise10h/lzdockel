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

(defun lzdockel-container-delete (item callback)
  "Delete the container referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (lzdockel-core-action-run
   (format "Delete container %s? " (lzdockel-core-get item 'Names))
   `("container" "rm" ,(lzdockel-core-get item 'ID))
   callback))

(defun lzdockel-container-restart (item callback)
  "Restart the container referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (lzdockel-core-action-run
   (format "Restart container %s? " (lzdockel-core-get item 'Names))
   `("container" "restart" ,(lzdockel-core-get item 'ID))
   callback))

(defun lzdockel-container-stop (item callback)
  "Stop the container referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (lzdockel-core-action-run
   (format "Stop container %s? " (lzdockel-core-get item 'Names))
   `("container" "stop" ,(lzdockel-core-get item 'ID))
   callback))

(provide 'lzdockel-container)
;;; lzdockel-container.el ends here
