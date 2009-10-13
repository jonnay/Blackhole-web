;;; Documentation Module
;; This is to aid in auto-generation of documentation.
;; The future plan is to allow it to work in two modes
;; Mode 1 is to document what exists, and stuff it in an org-mode file
;; Mode 2 is to snarf what exists, and prep it for inclusion into a literate org-mode file.
;; Mode 1 is first.

;;* imports

;;* exports



;;* list
(define (atom? obj)
  (and (not (pair? obj))
	   (not (list? obj))))

;;* documentor 
(define-type documentor
  parsed-structure
  (listeners init: '())
  (outputs init: '()))

;;* documentor listen
(define (documentor-add-listener! doc symbol listener)
  (documentor-listener-set! doc (cons (cons symbol listener) (documentor-listener doc))))

;;* documentor output
(define (documentor-add-output! doc output)
  (documentor-outputs-set! doc (cons output (documentor-outputs doc))))


;;* listen
(define (documentor-listener-registered? documentor symbol)
  (if (assoc symbol (documentor-listeners documentor))
	  #t
	  #f))

;;* listener 
(define (define-listener doc s l)
  (let ((binding (cadr l))
		(value (cddr l)))
	(if (or (list? binding)
			(equals? (car value) 'lambda))
		(documentor-add-output! (documentor-output-function binding value))
		(documentor-add-output! (documentor-output-value binding value)))))

;;* listener 
(define (structure-type-listener doc s l)
  (let ((binding (cadr l))
		(elemetns (cddr l)))
	(documentor-add-output! doc (documentor-output-structure binding elements))))

;;* main
(define (documentor-document file)
  (documentor-document-structure (read-all (open-input-file file)
										   read)))



(define (documentor-loop documentor node)
  (cond ((null? node) #f)
		((atom? node) #f)
		((and (list? node)
			  (documentor-listener-registered? documentor (car node)))
		 (documentor-execute-listeners documentor (car node) (node)))
		((list? (car node))
		 (documentor-loop documentor (car node))
		 (documentor-loop documentor (cdr node)))))

;;* listen 
(define (documentor-execute-listeners documentor symbol node)
  (define (loop lst)
	(cond ((equal? (car lst) symbol)
		   (progn
			((cdr lst) documentor symbol node)
			(loop (cdr lst))))
		  ((null? lst) #f)))
  (loop (documentor-listeners documentor)))

;;* main 
(define (documentor-document-structure str trans)
  (let ((d (make-documentor str)))
	(documentor-add-listener! d 'define define-listener)
	(documentor-add-listener! d 'define-structure define-structure-documentor-structure-type-listener)
	(documentor-loop d str)
	(documentor-output d trans)))


;;* output
(define (documentor-output documentor transformer)
  (map transformer
	   (documentor-outputs documentor)))

;;* transfor
(define identity (lambda (x) x))

;;* temp
(define in-file (read-all (open-input-file "~~/lib/modules/web/mysql/mysql.scm") read))

(define (test)
  (documentor-document-structure in-file identity))

(test)