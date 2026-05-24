;;; lzdockel-dashboard.el --- Unified dashboard view  -*- lexical-binding: t; -*-

;;; Code:

(require 'lzdockel-core)
(require 'lzdockel-container)
(require 'lzdockel-image)
(require 'lzdockel-volume)
(require 'lzdockel-network)
(require 'lzdockel-faces)

(defvar lzdockel-dashboard-sections
  '(("Containers" . lzdockel-container)
    ("Images" . lzdockel-image)
    ("Volumes" . lzdockel-volume)
    ("Networks" . lzdockel-network))
  "List of dashboard sections as (TITLE . MODULE) pairs.")

(defvar lzdockel-dashboard-current-section 0
  "Index of the currently focused section.")

(defvar lzdockel-dashboard-data nil
  "Alist storing data for each section: (SECTION-INDEX . DATA-LIST).")

(defvar lzdockel-dashboard-section-bounds nil
  "Alist storing buffer positions for each section: (SECTION-INDEX . (START . END)).")

(defvar lzdockel-dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'lzdockel-dashboard-next-section)
    (define-key map (kbd "<backtab>") #'lzdockel-dashboard-prev-section)
    (define-key map (kbd "S-<tab>") #'lzdockel-dashboard-prev-section)
    (define-key map (kbd "g") #'lzdockel-dashboard-refresh)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "n") #'lzdockel-dashboard-next-item)
    (define-key map (kbd "p") #'lzdockel-dashboard-prev-item)
    (define-key map (kbd "<down>") #'lzdockel-dashboard-next-item)
    (define-key map (kbd "<up>") #'lzdockel-dashboard-prev-item)
    map)
  "Keymap for `lzdockel-dashboard-mode'.")

(defface lzdockel-dashboard-section-header
  '((t :inherit font-lock-function-name-face :weight bold))
  "Face for section headers in the dashboard.")

(defface lzdockel-dashboard-section-active
  '((t :background "#3d5226" :weight bold))
  "Face for the active section header.")

(defface lzdockel-dashboard-item-selected
  '((t :background "#444444"))
  "Face for the selected item in a section.")

(defface lzdockel-dashboard-column-header
  '((t :inherit font-lock-comment-face :weight bold))
  "Face for column headers in sections.")

(defvar lzdockel-dashboard-column-headers
  '(("Containers" . "  %-12s %-30s %-20s %s")
    ("Images" . "  %-12s %-30s %-15s %s")
    ("Volumes" . "  %-15s %s")
    ("Networks" . "  %-12s %-25s %-15s %s"))
  "Format strings for column headers per section.")

(defvar lzdockel-dashboard-column-labels
  '(("Containers" . ["ID" "Image" "Created" "Name"])
    ("Images" . ["ID" "Repository" "Tag" "Size"])
    ("Volumes" . ["Driver" "Name"])
    ("Networks" . ["ID" "Name" "Driver" "Scope"]))
  "Column labels for each section.")

(define-derived-mode lzdockel-dashboard-mode special-mode "Lzdockel-Dashboard"
  "Major mode for the lzdockel unified dashboard."
  (setq buffer-read-only t)
  (hl-line-mode 1)
  (setq-local lzdockel-dashboard-current-section 0)
  (setq-local lzdockel-dashboard-data nil)
  (setq-local lzdockel-dashboard-section-bounds nil))

(defun lzdockel-dashboard--section-header (title index)
  "Return a formatted section header string for TITLE at INDEX."
  (let* ((active (= index lzdockel-dashboard-current-section))
         (face (if active 'lzdockel-dashboard-section-active 'lzdockel-dashboard-section-header))
         (marker (if active "▸ " "  ")))
    (concat (propertize (format "%s[%d]-%s" marker (1+ index) title) 'face face) "\n")))

(defun lzdockel-dashboard--column-header (section-name)
  "Return a formatted column header string for SECTION-NAME."
  (let* ((labels (cdr (assoc section-name lzdockel-dashboard-column-labels)))
         (fmt (cdr (assoc section-name lzdockel-dashboard-column-headers))))
    (if (and labels fmt)
        (concat (propertize (apply #'format fmt (append labels nil)) 'face 'lzdockel-dashboard-column-header) "\n")
      "")))

(defun lzdockel-dashboard--get (alist key)
  "Get VALUE from ALIST by KEY, handling both string and symbol keys."
  (or (cdr (assoc key alist))
      (cdr (assoc (symbol-name key) alist))
      ""))

(defun lzdockel-dashboard--container-active-p (container)
  "Return non-nil if CONTAINER is active (running)."
  (string-prefix-p "Up" (lzdockel-dashboard--get container 'Status)))

(defun lzdockel-dashboard--sort-containers (containers)
  "Sort CONTAINERS so active ones appear first."
  (sort (copy-sequence containers)
        (lambda (a b)
          (and (lzdockel-dashboard--container-active-p a)
               (not (lzdockel-dashboard--container-active-p b))))))

(defun lzdockel-dashboard--format-container (container)
  "Format a CONTAINER alist for display."
  (let* ((id (lzdockel-dashboard--get container 'ID))
         (short-id (substring id 0 (min 12 (length id))))
	 (image (lzdockel-dashboard--get container 'Image))
         (created (lzdockel-dashboard--get container 'RunningFor))
         (status (lzdockel-dashboard--get container 'Status))
         (names (lzdockel-dashboard--get container 'Names))
         (exited (string-prefix-p "Exited" status))
         (status-face (cond
                        ((string-prefix-p "Up" status) 'lzdockel-status-running)
                        ((string-prefix-p "Exited" status) 'lzdockel-status-exited)
                        (t nil)))
         (line (format "  %-12s %-30s %-20s %s"
                       (propertize short-id 'face 'lzdockel-image-id)
                       image
                       created
                       names)))
    (when exited
      (setq line (propertize line 'face 'lzdockel-dashboard-item-dim)))
    (concat line
            " "
            (if status-face (propertize status 'face status-face) ""))))

(defun lzdockel-dashboard--format-image (image)
  "Format an IMAGE alist for display."
  (let* ((id (lzdockel-dashboard--get image 'ID))
         (short-id (substring id 0 (min 12 (length id))))
         (repository (lzdockel-dashboard--get image 'Repository))
         (tag (lzdockel-dashboard--get image 'Tag))
         (size (lzdockel-dashboard--get image 'Size)))
    (format "  %-12s %-30s %-15s %s"
            (propertize short-id 'face 'lzdockel-image-id)
            repository
            tag
            size)))

(defun lzdockel-dashboard--format-volume (volume)
  "Format a VOLUME alist for display."
  (let ((driver (lzdockel-dashboard--get volume 'Driver))
        (name (lzdockel-dashboard--get volume 'Name)))
    (format "  %-15s %s" driver name)))

(defun lzdockel-dashboard--format-network (network)
  "Format a NETWORK alist for display."
  (let* ((id (lzdockel-dashboard--get network 'ID))
         (short-id (substring id 0 (min 12 (length id))))
         (name (lzdockel-dashboard--get network 'Name))
         (driver (lzdockel-dashboard--get network 'Driver))
         (scope (lzdockel-dashboard--get network 'Scope)))
    (format "  %-12s %-25s %-15s %s"
            (propertize short-id 'face 'lzdockel-image-id)
            name
            driver
            scope)))

(defun lzdockel-dashboard--format-item (item section-index)
  "Format ITEM for display based on SECTION-INDEX."
  (let ((section-name (car (nth section-index lzdockel-dashboard-sections))))
    (cond
     ((string= section-name "Containers") (lzdockel-dashboard--format-container item))
     ((string= section-name "Images") (lzdockel-dashboard--format-image item))
     ((string= section-name "Volumes") (lzdockel-dashboard--format-volume item))
     ((string= section-name "Networks") (lzdockel-dashboard--format-network item))
     (t (format "  %s" item)))))

(defun lzdockel-dashboard--render-section (title index data)
  "Render a section with TITLE, INDEX, and DATA items."
  (let ((start (point)))
    (insert (lzdockel-dashboard--section-header title index))
    (insert (lzdockel-dashboard--column-header title))
    (if (null data)
        (insert "  (empty)\n")
      (dolist (item data)
        (insert (lzdockel-dashboard--format-item item index) "\n")))
    (insert "\n")
    (cons index (cons start (point)))))

(defun lzdockel-dashboard--ascii-art ()
  "Return lzdockel title with theme-aware styling."
  (propertize "LZDockel" 'face 'lzdockel-dashboard-title))

(defun lzdockel-dashboard-render ()
  "Render the full dashboard with all sections."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (lzdockel-dashboard--ascii-art) "\n\n")
    ;; (insert (make-string 50 ?═) "\n\n")
    (setq lzdockel-dashboard-section-bounds nil)
    (dotimes (i (length lzdockel-dashboard-sections))
      (let* ((section (nth i lzdockel-dashboard-sections))
             (title (car section))
             (data (cdr (assoc i lzdockel-dashboard-data))))
        (push (lzdockel-dashboard--render-section title i (or data '()))
              lzdockel-dashboard-section-bounds)))
    (setq lzdockel-dashboard-section-bounds (nreverse lzdockel-dashboard-section-bounds))
    (goto-char (point-min))))

(defun lzdockel-dashboard-fetch-all ()
  "Fetch data for all sections and render the dashboard."
  (let ((pending (length lzdockel-dashboard-sections))
        (results '()))
    (dotimes (i (length lzdockel-dashboard-sections))
      (let ((section-idx i)
            (module (cdr (nth i lzdockel-dashboard-sections))))
          (let ((fetch-fn (intern (format "%s-list" (symbol-name module)))))
          (funcall fetch-fn
                   (lambda (data)
                     (when (eq section-idx 0)
                       (setq data (lzdockel-dashboard--sort-containers data)))
                     (push (cons section-idx data) results)
                     (setq pending (1- pending))
                     (when (zerop pending)
                       (when (buffer-live-p (get-buffer "*lzdockel-dashboard*"))
                         (with-current-buffer "*lzdockel-dashboard*"
                           (setq lzdockel-dashboard-data (nreverse results))
                           (lzdockel-dashboard-render)))))))))))

(defun lzdockel-dashboard-refresh ()
  "Refresh all dashboard data."
  (interactive)
  (lzdockel-dashboard-fetch-all))

(defun lzdockel-dashboard-next-section ()
  "Move to the next section."
  (interactive)
  (let ((count (length lzdockel-dashboard-sections)))
    (setq lzdockel-dashboard-current-section
          (mod (1+ lzdockel-dashboard-current-section) count)))
  (lzdockel-dashboard-render)
  (lzdockel-dashboard-goto-section lzdockel-dashboard-current-section))

(defun lzdockel-dashboard-prev-section ()
  "Move to the previous section."
  (interactive)
  (let ((count (length lzdockel-dashboard-sections)))
    (setq lzdockel-dashboard-current-section
          (mod (1- lzdockel-dashboard-current-section) count)))
  (lzdockel-dashboard-render)
  (lzdockel-dashboard-goto-section lzdockel-dashboard-current-section))

(defun lzdockel-dashboard-goto-section (index)
  "Move point to the start of section at INDEX."
  (let ((bounds (cdr (assoc index lzdockel-dashboard-section-bounds))))
    (when bounds
      (goto-char (car bounds)))))

(defun lzdockel-dashboard-next-item ()
  "Move to the next item within the current section."
  (interactive)
  (let ((bounds (cdr (assoc lzdockel-dashboard-current-section lzdockel-dashboard-section-bounds))))
    (when bounds
      (let ((section-end (cdr bounds)))
        (forward-line 1)
        (when (>= (point) section-end)
          (lzdockel-dashboard-next-section))))))

(defun lzdockel-dashboard-prev-item ()
  "Move to the previous item within the current section."
  (interactive)
  (let ((bounds (cdr (assoc lzdockel-dashboard-current-section lzdockel-dashboard-section-bounds))))
    (when bounds
      (let ((section-start (car bounds)))
        (forward-line -1)
        (when (< (point) section-start)
          (lzdockel-dashboard-prev-section))))))

(defun lzdockel-dashboard-get-selected-item ()
  "Return the currently selected item data from the active section."
  (let* ((section-idx lzdockel-dashboard-current-section)
         (data (cdr (assoc section-idx lzdockel-dashboard-data)))
         (bounds (cdr (assoc section-idx lzdockel-dashboard-section-bounds))))
    (when (and data bounds)
      (let* ((section-start (car bounds))
             (line-offset (- (line-number-at-pos) (line-number-at-pos section-start) 1)))
        (when (and (>= line-offset 0) (< line-offset (length data)))
          (nth line-offset data))))))

;;;###autoload
(defun lzdockel-dashboard ()
  "Open the lzdockel unified dashboard."
  (interactive)
  (let ((buf (get-buffer-create "*lzdockel-dashboard*")))
    (switch-to-buffer buf)
    (lzdockel-dashboard-mode)
    (lzdockel-dashboard-fetch-all)))

(provide 'lzdockel-dashboard)
;;; lzdockel-dashboard.el ends here
