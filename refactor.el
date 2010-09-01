;;; refactor.el --- refactoring tools


;;; Commentary:
;; 


;;; Code:

;;; TODO
;;  * prefixed name

(defvar isearch-lazy-highlight-last-string)

(defvar refactor-overlay nil)
(defvar refactor-region-start nil)
(defvar refactor-region-end nil)



(defun refactor-already-bounded (symbol start end)
  "SYMBOL is already bounded or not in region START END."
  (save-excursion
    (goto-char start)
    (and (re-search-forward (refactor-create-regexp symbol) nil t)
	 (< (point) end))))

(defun refactor-create-regexp (symbol)
  "Create SYMBOL exclusive regexp."
  (format "\\_<\\(%s\\)\\_>" (regexp-quote symbol)))

(defun refactor-dehighlight ()
  "Dehighlight `refactor-highlight'."
  (when refactor-overlay
    (delete-overlay refactor-overlay))
  (lazy-highlight-cleanup lazy-highlight-cleanup)
  (setq isearch-lazy-highlight-last-string nil))

(defun refactor-highlight (string beg fin)
  "Highlight STRING between BEG and FIN."
  (setq refactor-overlay (make-overlay beg fin))
  (overlay-put refactor-overlay 'priority 1001) ;higher than lazy overlays
  (overlay-put refactor-overlay 'face 'query-replace)
  (let ((isearch-string string)
	(isearch-regexp t)
	(search-whitespace-regexp nil)
	(isearch-case-fold-search nil))
    (isearch-lazy-highlight-new-loop refactor-region-start refactor-region-end)))

(defmacro refactor-with-file (file &rest form)
  `(let ((win (selected-window))
	 buffer opened)
     (if (setq buffer (get-file-buffer file))
	 (setq opened t)
       (setq buffer (find-file-noselect file)))
     (unwind-protect 
	 (with-current-buffer buffer
	   (save-window-excursion
	     (show-buffer win buffer)
	     (let (buffer-read-only)
	       ,@form)))
       (unless opened
	 (when (buffer-live-p buffer)
	   (unless (buffer-modified-p buffer)
	     (kill-buffer buffer)))))))

(put 'refactor-with-file 'lisp-indent-function 1)

(defun refactor-rename-region (symbol new &optional region)
  "Rename SYMBOL to NEW in REGION."
  (let ((start (if region (car region) (point-min)))
	(end (if region (cdr region) (save-excursion (goto-char (point-max)) (point-marker))))
	regexp)
    (when (or (not (refactor-already-bounded new start end))
	      (y-or-n-p (format "%s is already bound.  But rename? " new)))
      (save-excursion
	(setq refactor-region-start start)
	(setq refactor-region-end end)
	(goto-char start)
	(setq regexp (refactor-create-regexp symbol))
	(while (and (re-search-forward regexp nil t)
		    (< (point) end))
	  (goto-char (match-end 1))
	  (refactor-highlight regexp (match-beginning 1) (match-end 1))
	  (unwind-protect
	      (when (y-or-n-p "Rename? ")
		(replace-match new nil nil nil 1))
	    (refactor-dehighlight)))))))

(defun refactor-rename-symbol-read-args (hist-var)
  (let (current-name prompt new-name)
    (barf-if-buffer-read-only)
    (unless (setq current-name (thing-at-point 'symbol))
      (error "No symbol found at point"))
    (setq prompt (format "%s -> New-Name name: " current-name))
    (setq new-name (read-string prompt current-name hist-var))
    (when (string= current-name new-name)
      (error "No difference"))
    (list current-name new-name)))



(provide 'refactor)

;;; refactor.el ends here
