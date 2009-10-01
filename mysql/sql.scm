 ;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ;; GNU General Public License for more details.
 
 ;; You should have received a copy of the GNU General Public License
 ;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 
 ;; Copyright 2009 Andrew Whaley

 ;; SQL Abstraction layer for Scheme 

 ;; Defines generic SQL types and empty sql procedures that should be redefined by your SQL driver 


;;;
;;;; Generic SQL Types
;; 

;; SQL Error type
(define-structure sql-error
                  code
                  message)

;; Date/time types
(define-structure sql-datetime
                  year
                  month
                  date
                  hour
                  minute
                  second)

(define-structure sql-date
                  year
                  month
                  date)

(define-structure sql-time
                  hour
                  minute
                  second)

;;;
;;;; Procedure Bindings
;; 

;;;
;;;; Bindings for SQL abstraction layer
;;;
;; Drivers should redefine these procedures to implement the driver and use the generic types.
;; Users of the driver should use these procedures and not the native driver procedures. 
(define (sql-connect . args) (raise (make-sql-error -1 "No suitable SQL driver loaded.")))
(define (sql-change-schema new-schema-name . optional-connection) (raise (make-sql-error -1 "No suitable SQL driver loaded.")))
(define (sql-execute dynamic-statement-text . optional-connection) (raise (make-sql-error -1 "No suitable SQL driver loaded.")))
(define (sql-execute-dynamic statement-text . optional-connection) (raise (make-sql-error -1 "No suitable SQL driver loaded.")))
(define (sql-prepare-statement statement-text . optional-connection) (raise (make-sql-error -1 "No suitable SQL driver loaded.")))
(define (sql-execute-prepared-statement statement-reference list-of-parameters . optional-connection) (raise (make-sql-error -1 "No suitable SQL driver loaded.")))
(define (sql-close-statement statement-reference . optional-connection) (raise (make-sql-error -1 "No suitable SQL driver loaded.")))
(define (sql-close-connection  . optional-connection) (raise (make-sql-error -1 "No suitable SQL driver loaded.")))

;;;
;;;; Generic connection handling
;;;
(define current-sql-connection (make-parameter #f))

(define-macro (with-connection new-connection . expressions)
  `(let ((old-connection (current-sql-connection))) 
       (dynamic-wind 
         (lambda () (current-sql-connection ,new-connection)) 
         ,(append (list 'lambda '()) expressions) 
         (lambda () (current-sql-connection old-connection)
                    ))))
  
  

