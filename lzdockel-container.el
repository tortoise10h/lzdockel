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

(defun lzdockel-container-delete (id callback)
  "Delete container with ID asynchronously.
CALLBACK is called with (SUCCESS-P . MESSAGE)."
  (lzdockel-core-run-action callback "rm" id))

(defun lzdockel-container-restart (id callback)
  "Restart container with ID asynchronously.
CALLBACK is called with (SUCCESS-P . MESSAGE)."
  (lzdockel-core-run-action callback "restart" id))

(defun lzdockel-container-pause (id callback)
  "Pause or unpause container with ID based on PAUSED-P.
CALLBACK is called with (SUCCESS-P . MESSAGE)."
  (lzdockel-core-run-action callback "pause" id))

(defun lzdockel-container-unpause (id callback)
  "Unpause container with ID asynchronously.
CALLBACK is called with (SUCCESS-P . MESSAGE)."
  (lzdockel-core-run-action callback "unpause" id))

(provide 'lzdockel-container)
;;; lzdockel-container.el ends here
