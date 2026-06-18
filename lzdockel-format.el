;;; lzdockel-format.el --- Formatting helpers for lzdockel  -*- lexical-binding: t; -*-

;;; Code:

(defun lzdockel-format-ports (ports)
  "Simplify Docker PORTS string for compact display.
Extracts host-mapped ports, deduplicates IPv4/IPv6, and truncates."
  (if (or (null ports) (string-empty-p ports))
      ""
    (let* ((entries (split-string ports ", *" t))
           (mapped '())
           (exposed '())
           (seen '()))
      (dolist (entry entries)
        (cond
         ((string-match "\\(?:0\\.0\\.0\\.0\\|\\[::\\]\\):\\([0-9]+\\)->\\([0-9]+\\)/\\(.*\\)" entry)
          (let ((key (concat (match-string 1 entry) ":" (match-string 2 entry))))
            (unless (member key seen)
              (push key seen)
              (push (format "%s→%s" (match-string 1 entry) (match-string 2 entry)) mapped))))
         ((string-match "^\\([0-9]+\\)/" entry)
          (push (match-string 1 entry) exposed))))
      (let ((result (mapconcat #'identity (nreverse mapped) ", ")))
        (when exposed
          (when (> (length result) 0)
            (setq result (concat result ", ")))
          (setq result (concat result (mapconcat #'identity (nreverse exposed) ","))))
        (if (> (length result) 20)
            (concat (substring result 0 17) "...")
          result)))))

(provide 'lzdockel-format)
;;; lzdockel-format.el ends here
