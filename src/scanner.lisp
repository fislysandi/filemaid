(in-package :filemaid)

(defstruct file-object
  path
  name
  extension
  size
  created
  modified
  metadata)

(defun safe-file-size (path)
  "Return file size for PATH, or 0 when unreadable."
  (handler-case
      (with-open-file (stream path :direction :input :element-type '(unsigned-byte 8))
        (file-length stream))
    (error () 0)))

(defun safe-write-date (path)
  "Return write date for PATH, or NIL when unavailable."
  (handler-case
      (file-write-date path)
    (error () nil)))

(defun make-file-object-from-path (path)
  "Create a FILE-OBJECT from filesystem PATH metadata."
  (let* ((name (pathname-name path))
         (type (pathname-type path))
         (modified (safe-write-date path))
         (size (safe-file-size path)))
    (make-file-object
     :path (namestring path)
     :name (or name "")
     :extension (if type (string-downcase type) "")
     :size size
     :created nil
     :modified modified
     :metadata nil)))

(defun collect-directory-paths (directory recursive)
  "Collect file pathnames from DIRECTORY, optionally RECURSIVE."
  (let ((dir (ensure-directory-pathname directory)))
    (if recursive
        (labels ((collect (current)
                   (append (directory-files current)
                           (loop for subdir in (uiop:subdirectories current)
                                 append (collect subdir)))))
          (collect dir))
        (directory-files dir))))

(defun scan-directory (directory &key (recursive nil))
  "Scan DIRECTORY and return FILE-OBJECT instances.
When RECURSIVE is true, include nested subdirectories."
  (mapcar #'make-file-object-from-path
          (collect-directory-paths directory recursive)))
