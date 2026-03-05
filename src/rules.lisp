(in-package :filemaid)

(defstruct rule-definition
  name
  from
  priority
  predicate
  actions)

(defvar *rule-registry* nil)

(defun clear-rule-registry ()
  "Clear all registered rules in the in-memory registry."
  (setf *rule-registry* nil))

(defun register-rule (rule-definition)
  "Register RULE-DEFINITION and return it."
  (push rule-definition *rule-registry*)
  rule-definition)

(defun registered-rules ()
  "Return rules in registration order."
  (nreverse (copy-list *rule-registry*)))

(defmacro from (path)
  "Declare a source directory PATH for a rule."
  `(list :from ,path))

(defmacro priority (value)
  "Declare integer priority VALUE for a rule."
  `(list :priority ,value))

(defmacro move (destination)
  "Create a move action targeting DESTINATION directory."
  `(make-action-spec :type :move :argument ,destination))

(defmacro copy (destination)
  "Create a copy action targeting DESTINATION directory."
  `(make-action-spec :type :copy :argument ,destination))

(defmacro rename (new-name)
  "Create a rename action using NEW-NAME for the basename."
  `(make-action-spec :type :rename :argument ,new-name))

(defmacro delete ()
  "Create a delete action."
  `(make-action-spec :type :delete :argument nil))

(defmacro tag (label)
  "Create a tag action using LABEL metadata."
  `(make-action-spec :type :tag :argument ,label))

(defmacro extension (value)
  "Predicate helper that matches file extension VALUE."
  `(file-extension-p file ,value))

(defmacro pdf-contains (value)
  "Predicate helper that checks PDF text VALUE via bridge."
  `(pdf-contains-p file ,value))

(defun parse-rule-clauses (clauses)
  "Parse DSL CLAUSES into source, priority, predicate, and actions."
  (let ((source nil)
        (priority 0)
        (condition t)
        (actions '()))
    (dolist (clause clauses)
      (unless (consp clause)
        (error "Invalid rule clause: ~S" clause))
      (case (first clause)
        (from (setf source (cadr clause)))
        (priority (setf priority (cadr clause)))
        (when (setf condition (cadr clause)))
        ((move copy rename delete tag)
         (push clause actions))
        (otherwise (error "Unsupported rule clause: ~S" clause))))
    (values source priority condition (nreverse actions))))

(defmacro rule (name &body clauses)
  "Compile a user-facing rule NAME with DSL CLAUSES."
  (multiple-value-bind (source priority condition actions)
      (parse-rule-clauses clauses)
    `(make-rule-definition
      :name ',name
      :from ,source
      :priority ,priority
      :predicate (lambda (file)
                   ,condition)
      :actions (list ,@actions))))
