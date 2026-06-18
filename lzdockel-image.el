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

(defun lzdockel-image-delete (item callback)
  "Delete the image referenced by ITEM, with confirmation.
CALLBACK is called on success."
  (message "[DEBUG] lzdockel-image-delete called: %s:%s"
           (lzdockel-core-get item 'Repository)
           (lzdockel-core-get item 'Tag))
  (lzdockel-core-action-run
   (format "Delete image %s:%s? "
           (lzdockel-core-get item 'Repository)
           (lzdockel-core-get item 'Tag))
   `("image" "rm" ,(lzdockel-core-get item 'ID))
   callback))

(provide 'lzdockel-image)
;;; lzdockel-image.el ends here
