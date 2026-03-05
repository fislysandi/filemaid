(in-package :filemaid)

(defstruct action-spec
  type
  argument)

(defun ensure-target-path (directory file-object)
  "Build target pathname in DIRECTORY for FILE-OBJECT."
  (let ((dir (ensure-directory-pathname directory)))
    (merge-pathnames
     (make-pathname :name (file-object-name file-object)
                    :type (file-object-extension file-object))
     dir)))

(defun action-result (type file-object &key target dry-run)
  "Create a uniform action result plist."
  (list :action type
        :source (file-object-path file-object)
        :target (and target (namestring target))
        :dry-run dry-run))

(defun target-pathname-with-suffix (pathname suffix)
  "Return PATHNAME with SUFFIX appended to name component."
  (let ((name (or (pathname-name pathname) "file")))
    (make-pathname :name (format nil "~A-~D" name suffix)
                   :type (pathname-type pathname)
                   :defaults pathname)))

(defun next-available-pathname (pathname)
  "Return first non-existing pathname derived from PATHNAME."
  (loop for suffix from 1
        for candidate = (target-pathname-with-suffix pathname suffix)
        unless (probe-file candidate)
          do (return candidate)))

(defun delete-existing-target (target)
  "Delete existing TARGET file when present."
  (when (probe-file target)
    (delete-file target)))

(defun resolve-file-conflict (target policy)
  "Resolve TARGET conflict according to POLICY.
Returns two values: effective-target and skipped-p."
  (if (not (probe-file target))
      (values target nil)
      (case policy
        (:error (error "Target already exists: ~A" (namestring target)))
        (:overwrite
         (delete-existing-target target)
         (values target nil))
        (:skip
         (values target t))
        (:rename
         (values (next-available-pathname target) nil))
        (otherwise
         (error "Unsupported file conflict policy: ~S" policy)))))

(defun skipped-action-result (type file-object target dry-run)
  "Return action result marked as skipped."
  (append (action-result type file-object :target target :dry-run dry-run)
          (list :status :skipped)))

(defun apply-move-action (file-object destination dry-run file-conflict-policy)
  "Move FILE-OBJECT into DESTINATION, respecting DRY-RUN."
  (let* ((source (pathname (file-object-path file-object)))
         (target (ensure-target-path destination file-object)))
    (multiple-value-bind (resolved-target skipped-p)
        (resolve-file-conflict target file-conflict-policy)
      (cond
        (skipped-p
         (skipped-action-result :move file-object resolved-target dry-run))
        (t
         (unless dry-run
           (ensure-directories-exist resolved-target)
           (rename-file source resolved-target))
         (action-result :move file-object :target resolved-target :dry-run dry-run))))))

(defun apply-copy-action (file-object destination dry-run file-conflict-policy)
  "Copy FILE-OBJECT into DESTINATION, respecting DRY-RUN."
  (let* ((source (pathname (file-object-path file-object)))
         (target (ensure-target-path destination file-object)))
    (multiple-value-bind (resolved-target skipped-p)
        (resolve-file-conflict target file-conflict-policy)
      (cond
        (skipped-p
         (skipped-action-result :copy file-object resolved-target dry-run))
        (t
         (unless dry-run
           (ensure-directories-exist resolved-target)
           (copy-file source resolved-target))
         (action-result :copy file-object :target resolved-target :dry-run dry-run))))))

(defun apply-rename-action (file-object new-name dry-run file-conflict-policy)
  "Rename FILE-OBJECT basename to NEW-NAME, respecting DRY-RUN."
  (let* ((source (pathname (file-object-path file-object)))
         (target (make-pathname :name new-name
                                :type (pathname-type source)
                                :defaults source)))
    (multiple-value-bind (resolved-target skipped-p)
        (resolve-file-conflict target file-conflict-policy)
      (cond
        (skipped-p
         (skipped-action-result :rename file-object resolved-target dry-run))
        (t
         (unless dry-run
           (rename-file source resolved-target))
         (action-result :rename file-object :target resolved-target :dry-run dry-run))))))

(defun apply-delete-action (file-object dry-run)
  "Delete FILE-OBJECT path unless DRY-RUN is true."
  (unless dry-run
    (delete-file (pathname (file-object-path file-object))))
  (action-result :delete file-object :dry-run dry-run))

(defun apply-tag-action (file-object tag dry-run)
  "Return metadata tagging intent for FILE-OBJECT."
  (declare (ignore dry-run))
  (list :action :tag
        :source (file-object-path file-object)
        :tag tag
        :note "Tag action returns metadata intent; persistence strategy is caller-defined."))

(defun apply-action (action file-object &key (dry-run nil)
                                     (file-conflict-policy (file-conflict-policy)))
  "Apply ACTION-SPEC to FILE-OBJECT and return an operation result plist."
  (ecase (action-spec-type action)
    (:move (apply-move-action file-object (action-spec-argument action) dry-run file-conflict-policy))
    (:copy (apply-copy-action file-object (action-spec-argument action) dry-run file-conflict-policy))
    (:rename (apply-rename-action file-object (action-spec-argument action) dry-run file-conflict-policy))
    (:delete (apply-delete-action file-object dry-run))
    (:tag (apply-tag-action file-object (action-spec-argument action) dry-run))))
