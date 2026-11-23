;;; lzdockel-format.el --- Formatting helpers for lzdockel  -*- lexical-binding: t; -*-

;;; Code:

(defun lzdockel-format-ports (ports &optional max-width)
  "Simplify Docker PORTS string for compact display.
Extracts host-mapped ports and deduplicates IPv4/IPv6.
When MAX-WIDTH is a positive integer, truncate the result to fit
within MAX-WIDTH display columns using an ellipsis.  When MAX-WIDTH
is nil, return the full simplified port string."
  (if (or (null ports) (string-empty-p ports))
      ""
    (let* ((entries (split-string ports ", *" t))
           (mapped '())
           (exposed '())
           (seen '()))
      (dolist (entry entries)
        (cond
         ((string-match
           "\\(?:[0-9.]+\\|\\[[^]]+\\]\\|::\\):\\([0-9]+\\(?:-[0-9]+\\)?\\)->\\([0-9]+\\(?:-[0-9]+\\)?\\)/\\(.*\\)"
           entry)
          (let ((key (concat (match-string 1 entry) ":" (match-string 2 entry))))
            (unless (member key seen)
              (push key seen)
              (push (format "%s→%s" (match-string 1 entry) (match-string 2 entry)) mapped))))
         ((string-match "^\\([0-9]+\\(?:-[0-9]+\\)?\\)/" entry)
          (push (match-string 1 entry) exposed))))
      (let ((result (mapconcat #'identity (nreverse mapped) ", ")))
        (when exposed
          (when (> (length result) 0)
            (setq result (concat result ", ")))
          (setq result (concat result (mapconcat #'identity (nreverse exposed) ","))))
        (if (and (integerp max-width) (> max-width 0) (> (string-width result) max-width))
            (if (<= max-width 1)
                (truncate-string-to-width result max-width)
              (truncate-string-to-width result max-width nil nil "…"))
          result)))))

(provide 'lzdockel-format)
;;; lzdockel-format.el ends here
