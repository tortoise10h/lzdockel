;;; lzdockel-network.el --- Network list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)

(defun lzdockel-network-list (callback)
  "Fetch Docker networks asynchronously, calling CALLBACK with results.
CALLBACK receives a list of network alists."
  (lzdockel-core-run
   (lambda (output)
     (funcall callback (lzdockel-core-parse-json-lines output)))
   "network" "ls" "--format" "{{json .}}"))

(defun lzdockel-network-delete (id callback)
  "Delete network with ID asynchronously.
CALLBACK is called with (SUCCESS-P . MESSAGE)."
  (lzdockel-core-run-action callback "network" "rm" id))

(provide 'lzdockel-network)
;;; lzdockel-network.el ends here
