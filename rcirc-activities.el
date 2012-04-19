;; Infrastructure

(require 'cl)

(defvar rcirc-activities/activities nil
  "Alist of (buffer . activities), where `activities' is a set of
activity indicators; `activity', `talk', `mention'")

(defun rcirc-activities/add-activity (activity &optional buffer)
  "Add an activity indicator to the set of activities for the given or current buffer."
  (let* ((b (or buffer (current-buffer)))
         (entry (assoc b rcirc-activities/activities)))
    (when (not entry) ;; Doesn't hurt to make sure
      (setq entry (rcirc-activities/add-buffer b)))
    (let ((activities (cdr entry)))
      (unless (memq activity activities)
        (let ((updated-activities (cons activity activities)))
          (setcdr entry updated-activities)
          updated-activities)))))

(defun rcirc-activities/reset (&optional buffer)
  "Empty the activity indicators set of the given or current buffer."
  (let* ((b (or buffer (current-buffer)))
         (entry (assoc b rcirc-activities/activities)))
    (when entry
      (setcdr (assoc b rcirc-activities/activities) nil))))

(defun rcirc-activities/reset-if-buffer-in-window (&optional buffer)
  (let* ((b (or buffer (current-buffer))))
    (when (get-buffer-window b)
      (rcirc-activities/reset b))))

(defun rcirc-activities/add-buffer (&optional buffer)
  "Add an entry for the given or current buffer to the activities alist."
  (let* ((b (or buffer (current-buffer)))
         (entry (cons b nil)))
    (with-current-buffer b
      (add-hook 'window-configuration-change-hook 'rcirc-activities/reset-if-buffer-in-window nil t))
    (unless (assoc b rcirc-activities/activities)
      (add-to-list 'rcirc-activities/activities entry))
    entry))

(defun rcirc-activities/delete-buffer (&optional buffer)
  "Delete the entry for the given or current buffer from the activities alist."
  (let* ((b (or buffer (current-buffer))))
    (assq-delete-all b rcirc-activities/activities)))

(defun rcirc-activities/print-hook-function (process sender response target text)
  (unless (get-buffer-window)
    (rcirc-activities/add-activity 'activity)
    (when (string= response "PRIVMSG")
      (rcirc-activities/add-activity 'talk)
      (when (search (rcirc-nick process) text)
        (rcirc-activities/add-activity 'mention)))))

(add-hook 'rcirc-mode-hook 'rcirc-activities/add-buffer)
(add-hook 'rcirc-print-hooks 'rcirc-activities/print-hook-function)
(add-hook 'kill-buffer-hook 'rcirc-activities/delete-buffer)


;; Frontend

(defun rcirc-activities/construct-choice (entry)
  (let* ((b (car entry))
         (activities (cdr entry))
         (b-name (buffer-name b))
         (identifier (cond
                      ((memq 'mention  activities) "@")
                      ((memq 'talk     activities) ".")
                      ((memq 'activity activities) " "))))
    (when identifier
      (concat identifier " " b-name))))

(defun rcirc-activities/get-buffer-from-choice (choice)
  (substring choice 2))

(require 'ido)

(defun rcirc-activities/switch-to-buffer ()
  "Choose and switch to a buffer in which activities are present, using ido.
The marks on the left side of buffer names indicate what type of activities are present."
  (interactive)
  (let* ((choices (mapcar 'rcirc-activities/construct-choice rcirc-activities/activities))
         (choices (remove nil choices)))
    (if choices
        (let* ((choice (ido-completing-read "Jump to buffer: " choices))
               (b (rcirc-activities/get-buffer-from-choice choice)))
          (switch-to-buffer b))
      (message "No activities."))))


(provide 'rcirc-activities)
