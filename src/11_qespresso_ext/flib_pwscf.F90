!
!  the following is a partial import of the flib directory of espresso
!   provides small routines for other pwscf-imported subroutines
!

#if defined HAVE_CONFIG_H
#include "config.h"
#endif

module flib_pwscf

  implicit none

  contains 
!
! Copyright (C) 2001-2004 Carlo Cavazzoni and PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!-----------------------------------------------------------------------
FUNCTION matches( string1, string2 )
  !-----------------------------------------------------------------------
  !
  ! ... .TRUE. if string1 is contained in string2, .FALSE. otherwise
  !

!This section has been created automatically by the script Abilint (TD).
!Do not modify the following lines by hand.
#undef ABI_FUNC
#define ABI_FUNC 'matches'
!End of the abilint section

  IMPLICIT NONE
  !
  CHARACTER (LEN=*), INTENT(IN) :: string1, string2
  LOGICAL                       :: matches
  INTEGER                       :: len1, len2, l
  !
  !
  len1 = LEN_TRIM( string1 )
  len2 = LEN_TRIM( string2 )
  !
  DO l = 1, ( len2 - len1 + 1 )
     !   
     IF ( string1(1:len1) == string2(l:(l+len1-1)) ) THEN
        !
        matches = .TRUE.
        !
        RETURN
        !
     END IF
     !
  END DO
  !
  matches = .FALSE.
  ! 
  RETURN
  !
END FUNCTION matches
!
! Copyright (C) 2001-2004 Carlo Cavazzoni and PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!-----------------------------------------------------------------------
FUNCTION capital( in_char )
  !-----------------------------------------------------------------------
  !
  ! ... converts character to capital if lowercase
  ! ... copy character to output in all other cases
  !

!This section has been created automatically by the script Abilint (TD).
!Do not modify the following lines by hand.
#undef ABI_FUNC
#define ABI_FUNC 'capital'
!End of the abilint section

  IMPLICIT NONE
  !
  CHARACTER(LEN=1), INTENT(IN) :: in_char
  CHARACTER(LEN=1)             :: capital
  CHARACTER(LEN=26), PARAMETER :: lower = 'abcdefghijklmnopqrstuvwxyz', &
                                  upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  INTEGER                      :: i
  !
  !
  DO i=1, 26
     !
     IF ( in_char == lower(i:i) ) THEN
        !
        capital = upper(i:i)
        !
        RETURN
        !
     END IF
     !
  END DO
  !
  capital = in_char
  !
  RETURN
  !
END FUNCTION capital
!
!-----------------------------------------------------------------------
FUNCTION lowercase( in_char )
  !-----------------------------------------------------------------------
  !
  ! ... converts character to lowercase if capital
  ! ... copy character to output in all other cases
  !

!This section has been created automatically by the script Abilint (TD).
!Do not modify the following lines by hand.
#undef ABI_FUNC
#define ABI_FUNC 'lowercase'
!End of the abilint section

  IMPLICIT NONE
  !
  CHARACTER(LEN=1), INTENT(IN) :: in_char
  CHARACTER(LEN=1)             :: lowercase
  CHARACTER(LEN=26), PARAMETER :: lower = 'abcdefghijklmnopqrstuvwxyz', &
                                  upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  INTEGER                      :: i
  !
  !
  DO i=1, 26
     !
     IF ( in_char == upper(i:i) ) THEN
        !
        lowercase = lower(i:i)
        !
        RETURN
        !
     END IF
     !
  END DO
  !
  lowercase = in_char
  !
  RETURN
  !
END FUNCTION lowercase

subroutine errore (routine, error, code)

  use defs_basis, only: std_out,std_out_default

!This section has been created automatically by the script Abilint (TD).
!Do not modify the following lines by hand.
#undef ABI_FUNC
#define ABI_FUNC 'errore'
!End of the abilint section

  implicit none

  !args
  character(*), intent(in) :: routine
  character(*), intent(in) :: error
  integer, intent(in) :: code

  if (code == 0) return

  write(std_out,*) ' in subroutine : ', trim(routine)
  write(std_out,*) error
  write(std_out,*) 'error code ', code
  stop
end subroutine errore

end module flib_pwscf
