;;; lzdockel-network.el --- Network list mode  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)
(require 'lzdockel-inspect)

(defun lzdockel-network-list (callback)
  "Fetch Docker networks asynchronously, calling CALLBACK with results.
CALLBACK receives a list of network alists."
  (lzdockel-core-run
   (lambda (output)
     (funcall callback (lzdockel-core-parse-json-lines output)))
   "network" "ls" "--format" "{{json .}}"))

(defun lzdockel-network-delete (item callback)
  "Delete the network referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (lzdockel-core-action-run
   (format "Delete network %s? " (lzdockel-core-get item 'Name))
   `("network" "rm" ,(lzdockel-core-get item 'ID))
   callback))

(defun lzdockel-network-inspect (item &optional _callback)
  "Open an inspect buffer for the network referenced by ITEM.
CALLBACK is accepted for `lzdockel-dashboard-dispatch-action'
compatibility and ignored."
  (lzdockel-inspect-show "network" item))

(provide 'lzdockel-network)
;;; lzdockel-network.el ends here
