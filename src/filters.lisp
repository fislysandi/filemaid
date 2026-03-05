(in-package :filemaid)

(defun file-extension-p (file-object extension)
  "Return T when FILE-OBJECT extension equals EXTENSION."
  (string-equal (file-object-extension file-object) extension))

(defun file-name-contains-p (file-object needle)
  "Return T when NEEDLE appears in file name."
  (not (null (search (string-downcase needle)
                     (string-downcase (file-object-name file-object))))))

(defun pdf-contains-p (file-object text)
  "Optional PDF content filter via Python bridge."
  (and (string-equal (file-object-extension file-object) "pdf")
       (python-pdf-contains-p (file-object-path file-object) text)))
