MODULE COMP_FUNCTIONS

! I/O + OS functions

USE PRECISION_PARAMETERS 
IMPLICIT NONE 
CHARACTER(255), PARAMETER :: funcid='$Id$'
CHARACTER(255), PARAMETER :: funcrev='$Revision$'
CHARACTER(255), PARAMETER :: funcdate='$Date$'
 
CONTAINS

SUBROUTINE GET_REV_func(MODULE_REV,MODULE_DATE)
INTEGER,INTENT(INOUT) :: MODULE_REV
CHARACTER(255),INTENT(INOUT) :: MODULE_DATE

WRITE(MODULE_DATE,'(A)') funcrev(INDEX(funcrev,':')+1:LEN_TRIM(funcrev)-2)
READ (MODULE_DATE,'(I5)') MODULE_REV
WRITE(MODULE_DATE,'(A)') funcdate

END SUBROUTINE GET_REV_func

REAL(EB) FUNCTION SECOND()  ! Returns the CPU time in seconds.
REAL(FB) CPUTIME
CALL CPU_TIME(CPUTIME)
SECOND = CPUTIME
END FUNCTION SECOND


REAL(EB) FUNCTION WALL_CLOCK_TIME()  ! Returns the number of seconds since January 1, 2000, including leap years

! Thirty days hath September,
! April, June, and November.
! February has twenty-eight alone;
! All the rest have thirty-one,
! Excepting Leap-Year, that's the time
! When February's days are twenty-nine.

INTEGER :: DATE_TIME(8),WALL_CLOCK_SECONDS
CHARACTER(10) :: BIG_BEN(3)
! X_1 = common year, X_2 = leap year
INTEGER, PARAMETER :: S_PER_YEAR_1=31536000,S_PER_YEAR_2=31622400,S_PER_DAY=86400,S_PER_HOUR=3600,S_PER_MIN=60
INTEGER, PARAMETER, DIMENSION(12) :: ACCUMULATED_DAYS_1=(/0,31,59,90,120,151,181,212,243,273,304,334/), & 
                                     ACCUMULATED_DAYS_2=(/0,31,60,91,121,152,182,213,244,274,305,335/)
INTEGER :: YEAR_COUNT

CALL DATE_AND_TIME(BIG_BEN(1),BIG_BEN(2),BIG_BEN(3),DATE_TIME)
WALL_CLOCK_SECONDS = 0._EB
DO YEAR_COUNT=2001,DATE_TIME(1)
   !Leap year if divisible by 4 but not 100 unless by 400 (1900 no, 1904  yes, 2000 yes)
   IF (MOD(YEAR_COUNT,4)==0 .AND. (MOD(YEAR_COUNT,100)/=0 .OR. MOD(YEAR_COUNT,400)==0)) THEN
      WALL_CLOCK_SECONDS = WALL_CLOCK_SECONDS + S_PER_YEAR_2
   ELSE
      WALL_CLOCK_SECONDS = WALL_CLOCK_SECONDS + S_PER_YEAR_1
   ENDIF
ENDDO 
IF (MOD(DATE_TIME(1),4)==0 .AND. (MOD(DATE_TIME(1),100)/=0 .OR. MOD(DATE_TIME(1),400)==0 )) THEN
   WALL_CLOCK_SECONDS = WALL_CLOCK_SECONDS + S_PER_DAY*(ACCUMULATED_DAYS_2(DATE_TIME(2))+DATE_TIME(3))
ELSE
   WALL_CLOCK_SECONDS = WALL_CLOCK_SECONDS + S_PER_DAY*(ACCUMULATED_DAYS_1(DATE_TIME(2))+DATE_TIME(3))
ENDIF
WALL_CLOCK_SECONDS = WALL_CLOCK_SECONDS +  S_PER_HOUR*DATE_TIME(5) + S_PER_MIN*DATE_TIME(6) + DATE_TIME(7)
WALL_CLOCK_TIME    = WALL_CLOCK_SECONDS + DATE_TIME(8)*0.001_EB

END FUNCTION WALL_CLOCK_TIME


SUBROUTINE SHUTDOWN(MESSAGE)  ! Stops the code gracefully after writing a message
USE GLOBAL_CONSTANTS, ONLY: LU_ERR
CHARACTER(*) MESSAGE
WRITE(LU_ERR,'(/A)') TRIM(MESSAGE)
STOP
END SUBROUTINE SHUTDOWN
 

!!SUBROUTINE FLUSH_BUFFER(UNIT) ! FLUSH_BUFFER flushes the buffer for the named logical unit.
!!USE IFPORT  ! For Intel compilers
!!USE GLOBAL_CONSTANTS, ONLY: FLUSH_FILE_BUFFERS
!!INTEGER, INTENT(IN) :: UNIT
!!IF (FLUSH_FILE_BUFFERS) CALL FLUSH(UNIT)
!!END SUBROUTINE FLUSH_BUFFER
 

SUBROUTINE GET_INPUT_FILE ! Read the argument after the command
USE GLOBAL_CONSTANTS, ONLY: FN_INPUT
IF (FN_INPUT=='null') CALL GETARG(1,FN_INPUT)
END SUBROUTINE GET_INPUT_FILE


SUBROUTINE CHECKREAD(NAME,LU,IOS)
 
INTEGER :: II,IOS
INTEGER, INTENT(IN) :: LU
CHARACTER(4), INTENT(IN) :: NAME
CHARACTER(80) TEXT
 
IOS = 1
READLOOP: DO
   READ(LU,'(A)',END=10) TEXT
   TLOOP: DO II=1,72
      IF (TEXT(II:II)/='&' .AND. TEXT(II:II)/=' ') EXIT TLOOP
      IF (TEXT(II:II)=='&') THEN
         IF (TEXT(II+1:II+4)==NAME) THEN
            BACKSPACE(LU)
            IOS = 0
            EXIT READLOOP
         ELSE
            CYCLE READLOOP
         ENDIF
      ENDIF
   ENDDO TLOOP
ENDDO READLOOP
 
10 RETURN
END SUBROUTINE CHECKREAD

END MODULE COMP_FUNCTIONS



MODULE MEMORY_FUNCTIONS
USE PRECISION_PARAMETERS
USE MESH_VARIABLES
USE COMP_FUNCTIONS, ONLY : SHUTDOWN
IMPLICIT NONE

CONTAINS


SUBROUTINE ChkMemErr(CodeSect,VarName,IZERO)
 
! Memory checking routine
 
CHARACTER(*), INTENT(IN) :: CodeSect, VarName
INTEGER IZERO
CHARACTER(100) MESSAGE
 
IF (IZERO==0) RETURN
 
WRITE(MESSAGE,'(4A)') 'ERROR: Memory allocation failed for ', TRIM(VarName),' in the routine ',TRIM(CodeSect)
CALL SHUTDOWN(MESSAGE)

END SUBROUTINE ChkMemErr


SUBROUTINE RE_ALLOCATE_DROPLETS(CODE,NM,NOM,NEW_DROPS)
 
TYPE (DROPLET_TYPE), ALLOCATABLE, DIMENSION(:) :: DUMMY
INTEGER, INTENT(IN) :: CODE,NM,NOM,NEW_DROPS
TYPE (MESH_TYPE), POINTER :: M
TYPE(OMESH_TYPE), POINTER :: M2
 
SELECT CASE(CODE)
   CASE(1)
      M=>MESHES(NM)
      ALLOCATE(DUMMY(1:M%NLPDIM))
      DUMMY = M%DROPLET
      DEALLOCATE(M%DROPLET)
      ALLOCATE(M%DROPLET(M%NLPDIM+NEW_DROPS))
      M%DROPLET(1:M%NLPDIM) = DUMMY(1:M%NLPDIM)
      M%NLPDIM = M%NLPDIM+NEW_DROPS
   CASE(2)
      M2=>MESHES(NM)%OMESH(NOM)
      ALLOCATE(DUMMY(1:M2%N_DROP_ORPHANS_DIM))
      DUMMY = M2%DROPLET
      DEALLOCATE(M2%DROPLET)
      ALLOCATE(M2%DROPLET(M2%N_DROP_ORPHANS_DIM+NEW_DROPS))
      M2%DROPLET(1:M2%N_DROP_ORPHANS_DIM) = DUMMY(1:M2%N_DROP_ORPHANS_DIM)
      M2%N_DROP_ORPHANS_DIM = M2%N_DROP_ORPHANS_DIM + NEW_DROPS
END SELECT
DEALLOCATE(DUMMY)

END SUBROUTINE RE_ALLOCATE_DROPLETS

 
FUNCTION REALLOCATE(P,N1,N2)          
REAL(EB), POINTER, DIMENSION(:) :: P, REALLOCATE
INTEGER, INTENT(IN) :: N1,N2
INTEGER :: NOLD, IERR
CHARACTER(100) :: MESSAGE
ALLOCATE(REALLOCATE(N1:N2), STAT=IERR)
IF (IERR /= 0) THEN
   WRITE(MESSAGE,'(A)') 'ERROR: Memory allocation failed in REALLOCATE'
   CALL SHUTDOWN(MESSAGE)
ENDIF
IF (.NOT. ASSOCIATED(P)) RETURN
NOLD = MIN(SIZE(P), N2-N1+1)
REALLOCATE(N1:NOLD+N1-1) = P(N1:NOLD+N1-1)  ! Restore the contents of the reallocated array
DEALLOCATE(P) 
END FUNCTION REALLOCATE


SUBROUTINE RE_ALLOCATE_STRINGS(NM)
 
CHARACTER(50), ALLOCATABLE, DIMENSION(:) :: DUMMY
INTEGER, INTENT(IN) :: NM
TYPE (MESH_TYPE), POINTER :: M
 
M=>MESHES(NM)
ALLOCATE(DUMMY(1:M%N_STRINGS))
DUMMY = M%STRING
DEALLOCATE(M%STRING)
ALLOCATE(M%STRING(M%N_STRINGS_MAX+100))
M%STRING(1:M%N_STRINGS) = DUMMY(1:M%N_STRINGS)
M%N_STRINGS_MAX = M%N_STRINGS_MAX+100
DEALLOCATE(DUMMY)
 
END SUBROUTINE RE_ALLOCATE_STRINGS

END MODULE MEMORY_FUNCTIONS 

MODULE GEOMETRY_FUNCTIONS

! Functions for manipulating geometry

USE PRECISION_PARAMETERS
USE MESH_VARIABLES
USE GLOBAL_CONSTANTS
IMPLICIT NONE
 

CONTAINS
 

SUBROUTINE BLOCK_CELL(NM,I1,I2,J1,J2,K1,K2,IVAL,OBST_INDEX)

! Indicate which cells are blocked off
 
INTEGER :: NM,I1,I2,J1,J2,K1,K2,IVAL,I,J,K,OBST_INDEX,IC
TYPE (MESH_TYPE), POINTER :: M
 
M => MESHES(NM)
DO K=K1,K2
   DO J=J1,J2
      DO I=I1,I2
         IC = M%CELL_INDEX(I,J,K)
         SELECT CASE(IVAL)
            CASE(0) 
               M%SOLID(IC)        = .FALSE.
               M%OBST_INDEX_C(IC) = 0
            CASE(1)
               M%SOLID(IC)        = .TRUE.
               M%OBST_INDEX_C(IC) = OBST_INDEX
         END SELECT
      ENDDO
   ENDDO
ENDDO
 
END SUBROUTINE BLOCK_CELL
 
 

SUBROUTINE GET_N_LAYER_CELLS(DIFFUSIVITY,THICKNESS,STRETCH_FACTOR,CELL_SIZE_FACTOR,N_CELLS,DXMIN)

! Get number of wall cells in the layer

INTEGER, INTENT(OUT)  :: N_CELLS
REAL(EB), INTENT(OUT) :: DXMIN
REAL(EB), INTENT(IN)  :: DIFFUSIVITY,THICKNESS,STRETCH_FACTOR,CELL_SIZE_FACTOR
REAL(EB) :: DSUM
INTEGER  :: N, I

IF (THICKNESS.EQ.0._EB) THEN
   N_CELLS = 0
   DXMIN = 0._EB
   RETURN
ENDIF
SHRINK_LOOP: DO N=1,999
   DSUM = 0._EB
   SUM_LOOP: DO I=1,N
      DSUM = DSUM + STRETCH_FACTOR**(MIN(I-1,N-I))
   ENDDO SUM_LOOP
   IF ((THICKNESS/DSUM < CELL_SIZE_FACTOR*SQRT(DIFFUSIVITY)) .OR. (N==999)) THEN
      N_CELLS = N
      DXMIN = THICKNESS/DSUM
      EXIT SHRINK_LOOP
   ENDIF
ENDDO SHRINK_LOOP

END SUBROUTINE GET_N_LAYER_CELLS


SUBROUTINE GET_WALL_NODE_COORDINATES(N_CELLS,N_LAYERS,N_LAYER_CELLS, &
         SMALLEST_CELL_SIZE,STRETCH_FACTOR,X_S)

! Get the wall internal coordinates

INTEGER, INTENT(IN)     :: N_CELLS,N_LAYERS, N_LAYER_CELLS(N_LAYERS)
REAL(EB), INTENT(IN)    :: SMALLEST_CELL_SIZE(N_LAYERS),STRETCH_FACTOR
REAL(EB), INTENT(OUT)   :: X_S(0:N_CELLS)

INTEGER I, II, NL
REAL(EB) DX_S

   II = 0
   X_S(0) = 0._EB
   DO NL=1,N_LAYERS
      DO I=1,N_LAYER_CELLS(NL)
         II = II+1
         DX_S = SMALLEST_CELL_SIZE(NL)*STRETCH_FACTOR**(MIN(I-1,N_LAYER_CELLS(NL)-I))
         X_S(II) = X_S(II-1) + DX_S
      ENDDO
   ENDDO

END SUBROUTINE GET_WALL_NODE_COORDINATES


SUBROUTINE GET_WALL_NODE_WEIGHTS(N_CELLS,N_LAYERS,N_LAYER_CELLS, &
         THICKNESS,GEOMETRY,X_S,DX,RDX,RDXN,DX_WGT,DXF,DXB,LAYER_INDEX)

! Get the wall internal coordinates

INTEGER, INTENT(IN)     :: N_CELLS, N_LAYERS, N_LAYER_CELLS(N_LAYERS), GEOMETRY
REAL(EB), INTENT(IN)    :: X_S(0:N_CELLS),THICKNESS
INTEGER, INTENT(OUT)    :: LAYER_INDEX(0:N_CELLS+1)
REAL(EB), INTENT(OUT)   :: DX(1:N_CELLS),RDX(0:N_CELLS+1),RDXN(0:N_CELLS),DX_WGT(0:N_CELLS),DXF,DXB

INTEGER I, II, NL, I_GRAD
REAL(EB) R

SELECT CASE(GEOMETRY)
CASE(SURF_CARTESIAN)
   I_GRAD = 0
CASE(SURF_CYLINDRICAL)
   I_GRAD = 1
CASE(SURF_SPHERICAL)
   I_GRAD = 2
END SELECT

   II = 0
   DO NL=1,N_LAYERS
      DO I=1,N_LAYER_CELLS(NL)
         II = II + 1
         LAYER_INDEX(II) = NL
      ENDDO
   ENDDO
   LAYER_INDEX(0) = 1
   LAYER_INDEX(N_CELLS+1) = N_LAYERS
   DXF = X_S(1)       - X_S(0)
   DXB = X_S(N_CELLS) - X_S(N_CELLS-1)

! Compute dx_weight for each node (dx_weight is the ratio of cell size to the 
! combined size of the current and next cell)

   DO I=1,N_CELLS-1
      DX_WGT(I) = (X_S(I)-X_S(I-1))/(X_S(I+1)-X_S(I-1))
   ENDDO
   DX_WGT(0)       = 0.5_EB
   DX_WGT(N_CELLS) = 0.5_EB

! Compute dx and 1/dx for each node (dx is the distance from cell boundary to cell boundary)

   DO I=1,N_CELLS
      DX(I)  = X_S(I)-X_S(I-1)
      RDX(I) = 1._EB/DX(I)
   ENDDO
  ! Adjust 1/dx_n to 1/rdr for cylindrical case and 1/r^2dr for spaherical
   IF (GEOMETRY /=SURF_CARTESIAN) THEN
      DO I=1,N_CELLS
         R = THICKNESS-0.5_EB*(X_S(I)+X_S(I-1))
         RDX(I) = RDX(I)/R**I_GRAD
      ENDDO
   ENDIF
   RDX(0)         = RDX(1)
   RDX(N_CELLS+1) = RDX(N_CELLS)

! Compute 1/dx_n for each node (dx_n is the distance from cell center to cell center)

   DO I=1,N_CELLS-1
      RDXN(I) = 2._EB/(X_S(I+1)-X_S(I-1))
   ENDDO
   RDXN(0)       = 1._EB/(X_S(1)-X_S(0))
   RDXN(N_CELLS) = 1._EB/(X_S(N_CELLS)-X_S(N_CELLS-1))

! Adjust 1/dx_n to r/dr for cylindrical case and r^2/dr for spaherical

   IF (GEOMETRY /= SURF_CARTESIAN) THEN
      DO I=0,N_CELLS
         R = THICKNESS-X_S(I)
         RDXN(I) = RDXN(I)*R**I_GRAD
      ENDDO
   ENDIF

END SUBROUTINE GET_WALL_NODE_WEIGHTS


SUBROUTINE GET_INTERPOLATION_WEIGHTS(N_LAYERS,NWP,NWP_NEW,N_LAYER_CELLS,N_LAYER_CELLS_NEW, &
            X_S,X_S_NEW,INT_WGT)

INTEGER, INTENT(IN)  :: N_LAYERS,NWP,NWP_NEW,N_LAYER_CELLS(N_LAYERS),N_LAYER_CELLS_NEW(N_LAYERS)
REAL(EB), INTENT(IN) :: X_S(0:NWP), X_S_NEW(0:NWP_NEW)
REAL(EB), INTENT(OUT) :: INT_WGT(NWP_NEW,NWP)

REAL(EB) XUP,XLOW,XUP_NEW,XLOW_NEW,DX_NEW
INTEGER I, J, II, JJ, I_BASE, J_BASE, J_OLD,N
II = 0
JJ = 0
I_BASE = 0
J_BASE = 0

INT_WGT = 0._EB
DO N = 1,N_LAYERS
   J_OLD = 1
   DO I = 1,N_LAYER_CELLS_NEW(N)
      II       = I_BASE + I
      XUP_NEW  = X_S_NEW(II)
      XLOW_NEW = X_S_NEW(II-1)
      DX_NEW   = XUP_NEW - XLOW_NEW 
      DO J = J_OLD,N_LAYER_CELLS(N)
         JJ = J_BASE + J
         XUP =  X_S(JJ)
         XLOW = X_S(JJ-1)
         INT_WGT(II,JJ) = (MIN(XUP,XUP_NEW)-MAX(XLOW,XLOW_NEW))/DX_NEW
         IF (XUP .GE. XUP_NEW) EXIT
      ENDDO
      J_OLD = J
   ENDDO
   I_BASE = I_BASE + N_LAYER_CELLS_NEW(N)
   J_BASE = J_BASE + N_LAYER_CELLS(N)
ENDDO

END SUBROUTINE GET_INTERPOLATION_WEIGHTS


SUBROUTINE INTERPOLATE_WALL_ARRAY(NWP,NWP_NEW,INT_WGT,ARR)
INTEGER, INTENT(IN)  :: NWP,NWP_NEW
REAL(EB), INTENT(IN) :: INT_WGT(NWP_NEW,NWP)
REAL(EB) ARR(NWP),TMP(NWP)

INTEGER I,J

TMP = ARR
ARR = 0._EB
DO I = 1,NWP_NEW
DO J = 1,NWP
   ARR(I) = ARR(I) + INT_WGT(I,J)*TMP(J)
ENDDO
ENDDO

END SUBROUTINE INTERPOLATE_WALL_ARRAY

END MODULE GEOMETRY_FUNCTIONS 

 
MODULE PHYSICAL_FUNCTIONS

! Functions for physical quantities

USE PRECISION_PARAMETERS
USE GLOBAL_CONSTANTS
USE MESH_VARIABLES
IMPLICIT NONE

CONTAINS

SUBROUTINE GET_F_C(Z_1,Z_2,Z_3,F,C,Z_F)
!Returns progress variables for Mixture Fraction functions for suppression and CO production
REAL(EB) :: Z_F,Z,WGT,Z_3_MAX,ZZ
REAL(EB), INTENT(IN) :: Z_1,Z_2,Z_3
REAL(EB), INTENT(OUT) :: F,C
INTEGER :: IZ1,IZ2

ZZ = Z_1 + Z_2 + Z_3
WGT =MIN(ZZ*10000._EB,10000._EB)
IZ1 = FLOOR(WGT)
IZ2 = MIN(10000,IZ1+1)
WGT = WGT - IZ1

z1z2z3: IF(ZZ <= 0._EB .OR. ZZ >= 1._EB) THEN
   C = 0._EB
   F = 0._EB
   Z_F = REACTION(1)%Z_F
ELSE
   IF (Z_1==ZZ) THEN
      F = 1._EB
      C = 0._EB
      Z_F = REACTION(1)%Z_F
   ELSE
      IF (Z_2 == 0._EB) THEN
         C = 1._EB
         Z_F = REACTION(2)%Z_F
      ELSE
         C = Z_3 / (Z_3 + Z_2)
         Z_F = 1._EB/(1._EB+(1._EB - C)*REACTION(1)%Z_F_CONS + C * REACTION(2)%Z_F_CONS)
      ENDIF
      IF (ZZ < Z_F) THEN
         F = Z_1 / ZZ
      ELSE
         F = (Z_1 * (1._EB - Z_F) - ZZ + Z_F) / (Z_F * (1._EB - ZZ))      
      ENDIF      
      Z_3_MAX = (1._EB-WGT)*SPECIES(I_PROG_CO)%Z_MAX(IZ1)+ WGT*SPECIES(I_PROG_CO)%Z_MAX(IZ2)
      C = MAX(0._EB,MIN(1._EB,Z_3 / Z_3_MAX / (1._EB - F)))
   ENDIF
ENDIF z1z2z3
F = MIN(1._EB,MAX(0._EB,F))

END SUBROUTINE GET_F_C

SUBROUTINE GET_F(Z_1,Z_3,F,Z_F)
!Returns progress variables for Mixture Fraction functions for suppression only
REAL(EB), INTENT(IN) :: Z_1,Z_3,Z_F
REAL(EB), INTENT(OUT) :: F
REAL(EB) :: ZZ

ZZ = Z_1 + Z_3
IF (ZZ > Z_F) THEN
   IF (ZZ >= 1._EB) THEN
      F = 1._EB
   ELSE
      F = (Z_1 * (1._EB - Z_F) - ZZ + Z_F) / (Z_F * (1._EB - ZZ))
   ENDIF
ELSE
   IF (ZZ <= 0._EB) THEN
      F = 0._EB
   ELSE
      F = Z_1 / ZZ
   ENDIF
ENDIF
F = MIN(1._EB,MAX(0._EB,F))
   
END SUBROUTINE GET_F

SUBROUTINE GET_MASS_FRACTION2(Z1,Z2,Z3,INDEX,YY_SUM,Y_MF)
! Y_MF returns the mass fraction of species INDEX
INTEGER, INTENT(IN) :: INDEX
REAL(EB), INTENT(IN) :: Z1,Z2,Z3,YY_SUM
REAL(EB) :: Z_1,Z_2,Z_3,Y_MF,ZZ
TYPE(REACTION_TYPE), POINTER :: RN

IF (YY_SUM >=1._EB) THEN
   Y_MF = 0._EB
   RETURN
ELSE
   Z_1 = MAX(0._EB,Z1)/(1._EB - MAX(0._EB,YY_SUM))
   Z_2 = MAX(0._EB,Z2)/(1._EB - MAX(0._EB,YY_SUM))         
   Z_3 = MAX(0._EB,Z3)/(1._EB - MAX(0._EB,YY_SUM))          
   ZZ  = Z_1 + Z_2 + Z_3
ENDIF

IF (CO_PRODUCTION) THEN
   RN => REACTION(2)
ELSE
   RN => REACTION(1)
ENDIF

SELECT CASE(INDEX)
   CASE(FUEL_INDEX)
      Y_MF = Z_1 * RN%Y_F_INLET
   CASE(N2_INDEX)
      Y_MF = (1._EB - ZZ) * RN%Y_N2_INFTY + Z_1 * RN%Y_N2_INLET + (Z_2 + Z_3) * RN%Y_F_INLET / RN%MW_FUEL * MW_N2 * RN%NU_N2
   CASE(O2_INDEX)
      Y_MF = (1._EB - ZZ) * RN%Y_O2_INFTY - Z_3 * RN%Y_F_INLET / RN%MW_FUEL * MW_O2 * RN%NU_O2
      IF (CO_PRODUCTION) Y_MF = Y_MF - Z_2 * RN%Y_F_INLET / RN%MW_FUEL * MW_O2 * REACTION(1)%NU_O2
   CASE(CO_INDEX)
      IF (CO_PRODUCTION) THEN
         Y_MF = Z_2 * RN%Y_F_INLET / RN%MW_FUEL * MW_CO * REACTION(1)%NU_CO
      ELSE
         Y_MF = Z_3 * RN%Y_F_INLET / RN%MW_FUEL * MW_CO * RN%NU_CO
      ENDIF
   CASE(CO2_INDEX)
      Y_MF = Z_3 * RN%Y_F_INLET / RN%MW_FUEL * MW_CO2 * RN%NU_CO2
   CASE(H2O_INDEX)
      Y_MF = (Z_2 + Z_3) * RN%Y_F_INLET / RN%MW_FUEL * MW_H2O * RN%NU_H2O
   CASE(H2_INDEX)
      Y_MF = (Z_2 + Z_3) * RN%Y_F_INLET / RN%MW_FUEL * MW_H2 * RN%NU_H2  
   CASE(SOOT_INDEX)
      Y_MF = (Z_2 + Z_3) * RN%Y_F_INLET / RN%MW_FUEL * MW_SOOT * RN%NU_SOOT
   CASE(OTHER_INDEX)
      Y_MF = (Z_2 + Z_3) * RN%Y_F_INLET / RN%MW_FUEL * RN%MW_OTHER * RN%NU_OTHER
END SELECT

Y_MF = MIN(1._EB,MAX(0._EB,Y_MF)) * (1._EB - MAX(YY_SUM,0._EB))

END SUBROUTINE GET_MASS_FRACTION2

SUBROUTINE GET_MASS_FRACTION_ALL(Z1,Z2,Z3,YY_SUM,Y_MF)
! Y_MF returns the mass fraction of all mixture fraction species
REAL(EB), INTENT(IN) :: Z1,Z2,Z3,YY_SUM
REAL(EB) :: ZZ,Z_1,Z_2,Z_3,Y_MF(9)
TYPE(REACTION_TYPE), POINTER :: RN

IF (YY_SUM >=1._EB) THEN
   Y_MF = 0._EB
   RETURN
ELSE
   Z_1 = MAX(0._EB,Z1)/(1._EB - MAX(0._EB,YY_SUM))
   Z_2 = MAX(0._EB,Z2)/(1._EB - MAX(0._EB,YY_SUM))         
   Z_3 = MAX(0._EB,Z3)/(1._EB - MAX(0._EB,YY_SUM))          
   ZZ = Z_1 + Z_2 + Z_3
ENDIF

IF (CO_PRODUCTION) THEN
   RN => REACTION(2)
ELSE
   RN => REACTION(1)
ENDIF

Y_MF(FUEL_INDEX) = Z_1 * RN%Y_F_INLET

Y_MF(N2_INDEX) = (1._EB - ZZ) * RN%Y_N2_INFTY + Z_1 * RN%Y_N2_INLET + (Z_2 + Z_3) * RN%Y_F_INLET / RN%MW_FUEL * MW_N2 * RN%NU_N2

Y_MF(O2_INDEX) = (1._EB - ZZ) * RN%Y_O2_INFTY - Z_3 * RN%Y_F_INLET / RN%MW_FUEL * MW_O2 * RN%NU_O2
IF (CO_PRODUCTION) Y_MF(O2_INDEX) = Y_MF(O2_INDEX) - Z_2 * RN%Y_F_INLET / RN%MW_FUEL * MW_O2 * REACTION(1)%NU_O2

IF (CO_PRODUCTION) THEN
   Y_MF(CO_INDEX) = Z_2 * RN%Y_F_INLET / RN%MW_FUEL * MW_CO * REACTION(1)%NU_CO
ELSE
   Y_MF(CO_INDEX) = Z_3 * RN%Y_F_INLET / RN%MW_FUEL * MW_CO * RN%NU_CO
ENDIF

Y_MF(CO2_INDEX) = Z_3 * RN%Y_F_INLET / RN%MW_FUEL * MW_CO2 * RN%NU_CO2

Y_MF(H2O_INDEX) = (Z_2 + Z_3) * RN%Y_F_INLET / RN%MW_FUEL * MW_H2O * RN%NU_H2O

Y_MF(H2_INDEX) = (Z_2 + Z_3) * RN%Y_F_INLET / RN%MW_FUEL * MW_H2 * RN%NU_H2  

Y_MF(SOOT_INDEX) = (Z_2 + Z_3) * RN%Y_F_INLET / RN%MW_FUEL * MW_SOOT * RN%NU_SOOT

Y_MF(OTHER_INDEX) = (Z_2 + Z_3) * RN%Y_F_INLET / RN%MW_FUEL * RN%MW_OTHER * RN%NU_OTHER

Y_MF = MIN(1._EB,MAX(0._EB,Y_MF)) * (1._EB - MAX(YY_SUM,0._EB))

END SUBROUTINE GET_MASS_FRACTION_ALL

SUBROUTINE GET_MOLECULAR_WEIGHT2(Z1,Z2,Z3,YY_SUM, MW_MF)
! Y_MF returns the mass fraction of species INDEX
REAL(EB), INTENT(IN) :: Z1,Z2,Z3,YY_SUM
REAL(EB) :: Z_1,Z_2,Z_3,MW_MF,Y_MF(9)
TYPE(REACTION_TYPE), POINTER :: RN

IF (YY_SUM >=1._EB) THEN
   MW_MF = MW_AIR
   RETURN
ELSE
   Z_1 = MAX(0._EB,Z1)/(1._EB - MAX(0._EB,YY_SUM))
   Z_2 = MAX(0._EB,Z2)/(1._EB - MAX(0._EB,YY_SUM))         
   Z_3 = MAX(0._EB,Z3)/(1._EB - MAX(0._EB,YY_SUM))          
ENDIF

CALL GET_MASS_FRACTION_ALL(Z_1,Z_2,Z_3,0._EB,Y_MF)
RN => REACTION(1)

MW_MF = 1._EB/(Y_MF(FUEL_INDEX)/RN%MW_FUEL + Y_MF(O2_INDEX)/MW_O2     + Y_MF(N2_INDEX)/MW_N2   + &
               Y_MF(H2O_INDEX)/MW_H2O      + Y_MF(CO2_INDEX)/MW_CO2   + Y_MF(CO_INDEX)/MW_CO   + &
               Y_MF(H2_INDEX)/MW_H2        + Y_MF(SOOT_INDEX)/MW_SOOT + Y_MF(OTHER_INDEX)/RN%MW_OTHER)

END SUBROUTINE GET_MOLECULAR_WEIGHT2

SUBROUTINE GET_MU2(Z1,Z2,Z3,YY_SUM,MU_MF,ITMP)
! GET_MU returns the viscosity of the mixture fraction
INTEGER, INTENT(IN) :: ITMP
REAL(EB), INTENT(IN) :: Z1,Z2,Z3,YY_SUM
REAL(EB) :: Z_1,Z_2,Z_3,MU_MF,Y_MF(9),MW_MF
TYPE(SPECIES_TYPE), POINTER :: SS
TYPE(REACTION_TYPE), POINTER :: RN

IF (YY_SUM >=1._EB) THEN
   MU_MF = SPECIES(0)%MU(ITMP)
   RETURN
ELSE
   Z_1 = MAX(0._EB,Z1)/(1._EB - MAX(0._EB,YY_SUM))
   Z_2 = MAX(0._EB,Z2)/(1._EB - MAX(0._EB,YY_SUM))         
   Z_3 = MAX(0._EB,Z3)/(1._EB - MAX(0._EB,YY_SUM))          
ENDIF
CALL GET_MASS_FRACTION_ALL(Z_1,Z_2,Z_3,0._EB,Y_MF)

SS => SPECIES(I_FUEL)
RN => REACTION(1)

MW_MF = 1._EB/(Y_MF(FUEL_INDEX)/RN%MW_FUEL + Y_MF(O2_INDEX)/MW_O2     + Y_MF(N2_INDEX)/MW_N2   + &
        Y_MF(H2O_INDEX)/MW_H2O      + Y_MF(CO2_INDEX)/MW_CO2   + Y_MF(CO_INDEX)/MW_CO   + &
        Y_MF(H2_INDEX)/MW_H2        + Y_MF(SOOT_INDEX)/MW_SOOT + Y_MF(OTHER_INDEX)/RN%MW_OTHER)

MU_MF = (Y_MF(FUEL_INDEX)*SS%MU_MF2(FUEL_INDEX,ITMP)/RN%MW_FUEL + Y_MF(O2_INDEX)*SS%MU_MF2(O2_INDEX,ITMP)/MW_O2 + &
         Y_MF(N2_INDEX)*SS%MU_MF2(N2_INDEX,ITMP)/MW_N2          + Y_MF(H2O_INDEX)*SS%MU_MF2(H2O_INDEX,ITMP)/MW_H2O + & 
         Y_MF(CO2_INDEX)*SS%MU_MF2(CO2_INDEX,ITMP)/MW_CO2       + Y_MF(CO_INDEX)*SS%MU_MF2(CO_INDEX,ITMP)/MW_CO   + &
         Y_MF(H2_INDEX)*SS%MU_MF2(H2_INDEX,ITMP)/MW_H2          + Y_MF(SOOT_INDEX)*SS%MU_MF2(SOOT_INDEX,ITMP)/MW_SOOT + &
         Y_MF(OTHER_INDEX)*SS%MU_MF2(OTHER_INDEX,ITMP)/RN%MW_OTHER) * MW_MF

END SUBROUTINE GET_MU2

SUBROUTINE GET_D2(Z1,Z2,Z3,YY_SUM,D_MF,ITMP)
! GET_D returns the diffusivity of the mixture fraction
INTEGER, INTENT(IN) :: ITMP
REAL(EB), INTENT(IN) :: Z1,Z2,Z3,YY_SUM
REAL(EB) :: Z_1,Z_2,Z_3,D_MF,Y_MF(9)
TYPE(SPECIES_TYPE), POINTER :: SS

IF (YY_SUM >=1._EB) THEN
   D_MF = SPECIES(0)%D(ITMP)
   RETURN
ELSE
   Z_1 = MAX(0._EB,Z1)/(1._EB - MAX(0._EB,YY_SUM))
   Z_2 = MAX(0._EB,Z2)/(1._EB - MAX(0._EB,YY_SUM))         
   Z_3 = MAX(0._EB,Z3)/(1._EB - MAX(0._EB,YY_SUM))          
ENDIF

CALL GET_MASS_FRACTION_ALL(Z_1,Z_2,Z_3,0._EB,Y_MF)
SS => SPECIES(I_FUEL)

D_MF = DOT_PRODUCT(Y_MF,SS%D_MF2(:,ITMP))

END SUBROUTINE GET_D2

SUBROUTINE GET_CP2(Z1,Z2,Z3,YY_SUM,CP_MF,ITMP)
! GET_D returns the specific heat of the mixture fraction
INTEGER, INTENT(IN) :: ITMP
REAL(EB), INTENT(IN) :: Z1,Z2,Z3,YY_SUM
REAL(EB) :: Z_1,Z_2,Z_3,CP_MF,Y_MF(9)
TYPE(SPECIES_TYPE), POINTER :: SS

IF (YY_SUM >=1._EB) THEN
   CP_MF = SPECIES(0)%CP(ITMP)
   RETURN
ELSE
   Z_1 = MAX(0._EB,Z1)/(1._EB - MAX(0._EB,YY_SUM))
   Z_2 = MAX(0._EB,Z2)/(1._EB - MAX(0._EB,YY_SUM))         
   Z_3 = MAX(0._EB,Z3)/(1._EB - MAX(0._EB,YY_SUM))          
ENDIF

CALL GET_MASS_FRACTION_ALL(Z_1,Z_2,Z_3,0._EB,Y_MF)
SS => SPECIES(I_FUEL)

CP_MF = DOT_PRODUCT(Y_MF,SS%CP_MF2(:,ITMP))

END SUBROUTINE GET_CP2

SUBROUTINE GET_K2(Z1,Z2,Z3,YY_SUM,K_MF,ITMP)
! GET_D returns the specific heat of the mixture fraction
INTEGER, INTENT(IN) :: ITMP
REAL(EB), INTENT(IN) :: Z1,Z2,Z3,YY_SUM
REAL(EB) :: Z_1,Z_2,Z_3,K_MF,Y_MF(9),MW_MF
TYPE(SPECIES_TYPE), POINTER :: SS
TYPE(REACTION_TYPE), POINTER :: RN

IF (YY_SUM >=1._EB) THEN
   K_MF = SPECIES(0)%K(ITMP)
   RETURN
ELSE
   Z_1 = MAX(0._EB,Z1)/(1._EB - MAX(0._EB,YY_SUM))
   Z_2 = MAX(0._EB,Z2)/(1._EB - MAX(0._EB,YY_SUM))         
   Z_3 = MAX(0._EB,Z3)/(1._EB - MAX(0._EB,YY_SUM))          
ENDIF

CALL GET_MASS_FRACTION_ALL(Z_1,Z_2,Z_3,0._EB,Y_MF)
SS => SPECIES(I_FUEL)
RN => REACTION(1)

MW_MF = 1._EB/(Y_MF(FUEL_INDEX)/RN%MW_FUEL + Y_MF(O2_INDEX)/MW_O2     + Y_MF(N2_INDEX)/MW_N2   + &
        Y_MF(H2O_INDEX)/MW_H2O      + Y_MF(CO2_INDEX)/MW_CO2   + Y_MF(CO_INDEX)/MW_CO   + &
        Y_MF(H2_INDEX)/MW_H2        + Y_MF(SOOT_INDEX)/MW_SOOT + Y_MF(OTHER_INDEX)/RN%MW_OTHER)

K_MF = (Y_MF(FUEL_INDEX)*SS%K_MF2(FUEL_INDEX,ITMP)/RN%MW_FUEL + Y_MF(O2_INDEX)*SS%K_MF2(O2_INDEX,ITMP)/MW_O2 + &
        Y_MF(N2_INDEX)*SS%K_MF2(N2_INDEX,ITMP)/MW_N2          + Y_MF(H2O_INDEX)*SS%K_MF2(H2O_INDEX,ITMP)/MW_H2O + & 
        Y_MF(CO2_INDEX)*SS%K_MF2(CO2_INDEX,ITMP)/MW_CO2       + Y_MF(CO_INDEX)*SS%K_MF2(CO_INDEX,ITMP)/MW_CO   + &
        Y_MF(H2_INDEX)*SS%K_MF2(H2_INDEX,ITMP)/MW_H2          + Y_MF(SOOT_INDEX)*SS%K_MF2(SOOT_INDEX,ITMP)/MW_SOOT + &
        Y_MF(OTHER_INDEX)*SS%K_MF2(OTHER_INDEX,ITMP)/RN%MW_OTHER) * MW_MF

END SUBROUTINE GET_K2

REAL(EB) FUNCTION DRAG(RE)
 
! Droplet drag coefficient

REAL(EB) :: RE
 
IF (RE<=1._EB) THEN
   DRAG = 24._EB/RE
ELSEIF (RE>1._EB .AND. RE<1000._EB) THEN
   DRAG = 24._EB*(1._EB+0.15_EB*RE**0.687_EB)/RE
ELSEIF (RE>=1000._EB) THEN
   DRAG = 0.44_EB
ENDIF
 
END FUNCTION DRAG


SUBROUTINE DROPLET_SIZE_DISTRIBUTION(DM,RR,CNF,NPT,GAMMA,SIGMA)
 
! Compute droplet Cumulative Number Fraction (CNF)
 
REAL(EB), INTENT(IN) :: DM,GAMMA,SIGMA
INTEGER, INTENT(IN) :: NPT
REAL(EB) :: SUM1,DD1,DI,ETRM,GFAC,SFAC
INTEGER  :: J
REAL(EB), INTENT(OUT) :: RR(0:NPT),CNF(0:NPT)
 
RR(0)  = 0._EB
CNF(0) = 0._EB
SUM1   = 0._EB
DD1    = (-LOG(1._EB-0.99_EB)/0.693_EB)**(1._EB/GAMMA)*DM/REAL(NPT,EB)
GFAC   = 0.693_EB*GAMMA*DD1/(DM**GAMMA)
SFAC   = DD1/(SQRT(TWOPI)*SIGMA)
 
INTLOOP: DO J=1,NPT
   DI = (J-.5_EB)*DD1
   RR(J) = .5_EB*DI
   IF (DI<=DM) THEN
      ETRM = EXP(-(LOG(DI/DM))**2/(2._EB*SIGMA**2))
      SUM1 = SUM1 + (SFAC/DI**4)*ETRM
   ELSE
      ETRM = EXP(-0.693_EB*(DI/DM)**GAMMA)
      SUM1 = SUM1 + GFAC*DI**(GAMMA-4._EB)*ETRM
   ENDIF
   CNF(J) = SUM1
ENDDO INTLOOP
 
CNF = CNF/SUM1
 
END SUBROUTINE DROPLET_SIZE_DISTRIBUTION


END MODULE PHYSICAL_FUNCTIONS



 
MODULE MATH_FUNCTIONS

USE PRECISION_PARAMETERS
IMPLICIT NONE 
 
CONTAINS
 
REAL(EB) FUNCTION AFILL(A111,A211,A121,A221,A112,A212,A122,A222,P,R,S)
! Linear interpolation function
REAL(EB) :: A111,A211,A121,A221,A112,A212,A122,A222,P,R,S,PP,RR,SS
PP = 1._EB-P
RR = 1._EB-R
SS = 1._EB-S
AFILL = ((PP*A111+P*A211)*RR+(PP*A121+P*A221)*R)*SS+((PP*A112+P*A212)*RR+(PP*A122+P*A222)*R)*S
END FUNCTION AFILL
 

REAL(EB) FUNCTION AFILL2(A,I,J,K,P,R,S)
! Linear interpolation function. Same as AFILL, only it reads in entire array.
REAL(EB), INTENT(IN), DIMENSION(0:,0:,0:) :: A
INTEGER, INTENT(IN) :: I,J,K
REAL(EB) A111,A211,A121,A221,A112,A212,A122,A222,P,R,S,PP,RR,SS
A111 = A(I,J,K)
A211 = A(I+1,J,K)
A121 = A(I,J+1,K)
A221 = A(I+1,J+1,K)
A112 = A(I,J,K+1)
A212 = A(I+1,J,K+1)
A122 = A(I,J+1,K+1)
A222 = A(I+1,J+1,K+1)
PP = 1._EB-P
RR = 1._EB-R
SS = 1._EB-S
AFILL2 = ((PP*A111+P*A211)*RR+(PP*A121+P*A221)*R)*SS+ ((PP*A112+P*A212)*RR+(PP*A122+P*A222)*R)*S
END FUNCTION AFILL2
 

REAL(EB) FUNCTION POLYVAL(N,TEMP,COEF)
! Calculate the value of polynomial function.
INTEGER N,I
REAL(EB) TEMP, COEF(N), VAL
VAL = 0._EB
DO I=1,N
   VAL  = VAL  + COEF(I)*TEMP**(I-1)
ENDDO
POLYVAL = VAL
END FUNCTION POLYVAL
 
 
SUBROUTINE GET_RAMP_INDEX(ID,TYPE,RAMP_INDEX)
USE GLOBAL_CONSTANTS, ONLY: N_RAMP,RAMP_ID,RAMP_TYPE
CHARACTER(*), INTENT(IN) :: ID,TYPE
INTEGER, INTENT(OUT) :: RAMP_INDEX
INTEGER :: NR
 
IF (ID=='null') THEN
   RAMP_INDEX = 0
   RETURN
ENDIF
 
SEARCH: DO NR=1,N_RAMP
   IF (ID==RAMP_ID(NR)) THEN
      RAMP_INDEX = NR
      RETURN
   ENDIF
ENDDO SEARCH
 
N_RAMP                = N_RAMP + 1
RAMP_INDEX            = N_RAMP
RAMP_ID(RAMP_INDEX)   = ID
RAMP_TYPE(RAMP_INDEX) = TYPE
END SUBROUTINE GET_RAMP_INDEX

SUBROUTINE GET_TABLE_INDEX(ID,TYPE,TABLE_INDEX)
USE GLOBAL_CONSTANTS, ONLY: N_TABLE,TABLE_ID,TABLE_TYPE
CHARACTER(*), INTENT(IN) :: ID
INTEGER, INTENT(IN) :: TYPE
INTEGER, INTENT(OUT) :: TABLE_INDEX
INTEGER :: NT
 
IF (ID=='null') THEN
   TABLE_INDEX = 0
   RETURN
ENDIF
 
SEARCH: DO NT=1,N_TABLE
   IF (ID==TABLE_ID(NT)) THEN
      TABLE_INDEX = NT
      RETURN
   ENDIF
ENDDO SEARCH
 
N_TABLE                = N_TABLE + 1
TABLE_INDEX            = N_TABLE
TABLE_ID(TABLE_INDEX)   = ID
TABLE_TYPE(TABLE_INDEX) = TYPE

END SUBROUTINE GET_TABLE_INDEX

REAL(EB) FUNCTION EVALUATE_RAMP(RAMP_INPUT,TAU,RAMP_INDEX)
USE TYPES, ONLY: RAMPS
USE DEVICE_VARIABLES, ONLY: DEVICE
USE CONTROL_VARIABLES, ONLY:CONTROL

! General time ramp up
 
REAL(EB), INTENT(IN) :: RAMP_INPUT,TAU
REAL(EB):: RAMP_POSITION
INTEGER,INTENT(IN)   :: RAMP_INDEX

SELECT CASE(RAMP_INDEX)
   CASE(-2)
      EVALUATE_RAMP = MAX(TANH(RAMP_INPUT/TAU),0._EB)
   CASE(-1)
      EVALUATE_RAMP = MIN( (RAMP_INPUT/TAU)**2 , 1.0_EB )
   CASE( 0)
      EVALUATE_RAMP = 1._EB
   CASE(1:)
 
      IF (RAMPS(RAMP_INDEX)%DEVC_INDEX > 0) THEN
         IF (DEVICE(RAMPS(RAMP_INDEX)%DEVC_INDEX)%CURRENT_STATE) THEN
            EVALUATE_RAMP = RAMPS(RAMP_INDEX)%VALUE
         ELSE
            RAMP_POSITION = MAX(0._EB,MIN(RAMPS(RAMP_INDEX)%SPAN,RAMP_INPUT - RAMPS(RAMP_INDEX)%T_MIN))
            EVALUATE_RAMP = RAMPS(RAMP_INDEX)%INTERPOLATED_DATA(NINT(RAMP_POSITION/RAMPS(RAMP_INDEX)%DT))
         ENDIF
      ELSEIF(RAMPS(RAMP_INDEX)%CTRL_INDEX > 0) THEN
         IF (CONTROL(RAMPS(RAMP_INDEX)%CTRL_INDEX)%CURRENT_STATE) THEN
            EVALUATE_RAMP = RAMPS(RAMP_INDEX)%VALUE
         ELSE
            RAMP_POSITION = MAX(0._EB,MIN(RAMPS(RAMP_INDEX)%SPAN,RAMP_INPUT - RAMPS(RAMP_INDEX)%T_MIN))
            EVALUATE_RAMP = RAMPS(RAMP_INDEX)%INTERPOLATED_DATA(NINT(RAMP_POSITION/RAMPS(RAMP_INDEX)%DT))
         ENDIF
      ELSE
         RAMP_POSITION = MAX(0._EB,MIN(RAMPS(RAMP_INDEX)%SPAN,RAMP_INPUT - RAMPS(RAMP_INDEX)%T_MIN))
         EVALUATE_RAMP = RAMPS(RAMP_INDEX)%INTERPOLATED_DATA(NINT(RAMP_POSITION/RAMPS(RAMP_INDEX)%DT))
      ENDIF
      RAMPS(RAMP_INDEX)%VALUE = EVALUATE_RAMP
END SELECT
 
END FUNCTION EVALUATE_RAMP

 
REAL(EB) FUNCTION ERFC(X)
 
! Complimentary ERF function
 
REAL(EB), INTENT(IN) :: X
REAL(EB) ERFCS(13), ERFCCS(24), ERC2CS(23),XSML,XMAX,SQEPS,SQRTPI,Y
DATA ERFCS( 1) /   -.049046121234691808_EB /
DATA ERFCS( 2) /   -.14226120510371364_EB /
DATA ERFCS( 3) /    .010035582187599796_EB /
DATA ERFCS( 4) /   -.000576876469976748_EB /
DATA ERFCS( 5) /    .000027419931252196_EB /
DATA ERFCS( 6) /   -.000001104317550734_EB /
DATA ERFCS( 7) /    .000000038488755420_EB /
DATA ERFCS( 8) /   -.000000001180858253_EB /
DATA ERFCS( 9) /    .000000000032334215_EB /
DATA ERFCS(10) /   -.000000000000799101_EB /
DATA ERFCS(11) /    .000000000000017990_EB /
DATA ERFCS(12) /   -.000000000000000371_EB /
DATA ERFCS(13) /    .000000000000000007_EB /
DATA ERC2CS( 1) /   -.069601346602309501_EB /
DATA ERC2CS( 2) /   -.041101339362620893_EB /
DATA ERC2CS( 3) /    .003914495866689626_EB /
DATA ERC2CS( 4) /   -.000490639565054897_EB /
DATA ERC2CS( 5) /    .000071574790013770_EB /
DATA ERC2CS( 6) /   -.000011530716341312_EB /
DATA ERC2CS( 7) /    .000001994670590201_EB /
DATA ERC2CS( 8) /   -.000000364266647159_EB /
DATA ERC2CS( 9) /    .000000069443726100_EB /
DATA ERC2CS(10) /   -.000000013712209021_EB /
DATA ERC2CS(11) /    .000000002788389661_EB /
DATA ERC2CS(12) /   -.000000000581416472_EB /
DATA ERC2CS(13) /    .000000000123892049_EB /
DATA ERC2CS(14) /   -.000000000026906391_EB /
DATA ERC2CS(15) /    .000000000005942614_EB /
DATA ERC2CS(16) /   -.000000000001332386_EB /
DATA ERC2CS(17) /    .000000000000302804_EB /
DATA ERC2CS(18) /   -.000000000000069666_EB /
DATA ERC2CS(19) /    .000000000000016208_EB /
DATA ERC2CS(20) /   -.000000000000003809_EB /
DATA ERC2CS(21) /    .000000000000000904_EB /
DATA ERC2CS(22) /   -.000000000000000216_EB /
DATA ERC2CS(23) /    .000000000000000052_EB /
DATA ERFCCS( 1) /     0.0715179310202925_EB /
DATA ERFCCS( 2) /   -.026532434337606719_EB /
DATA ERFCCS( 3) /    .001711153977920853_EB /
DATA ERFCCS( 4) /   -.000163751663458512_EB /
DATA ERFCCS( 5) /    .000019871293500549_EB /
DATA ERFCCS( 6) /   -.000002843712412769_EB /
DATA ERFCCS( 7) /    .000000460616130901_EB /
DATA ERFCCS( 8) /   -.000000082277530261_EB /
DATA ERFCCS( 9) /    .000000015921418724_EB /
DATA ERFCCS(10) /   -.000000003295071356_EB /
DATA ERFCCS(11) /    .000000000722343973_EB /
DATA ERFCCS(12) /   -.000000000166485584_EB /
DATA ERFCCS(13) /    .000000000040103931_EB /
DATA ERFCCS(14) /   -.000000000010048164_EB /
DATA ERFCCS(15) /    .000000000002608272_EB /
DATA ERFCCS(16) /   -.000000000000699105_EB /
DATA ERFCCS(17) /    .000000000000192946_EB /
DATA ERFCCS(18) /   -.000000000000054704_EB /
DATA ERFCCS(19) /    .000000000000015901_EB /
DATA ERFCCS(20) /   -.000000000000004729_EB /
DATA ERFCCS(21) /    .000000000000001432_EB /
DATA ERFCCS(22) /   -.000000000000000439_EB /
DATA ERFCCS(23) /    .000000000000000138_EB /
DATA ERFCCS(24) /   -.000000000000000048_EB /
DATA SQRTPI /1.7724538509055160_EB/
 
XSML = -200._EB
XMAX = 200._EB
SQEPS = 0.001_EB
 
IF (X<=XSML) THEN
   ERFC = 2._EB
ELSE
 
   IF (X<=XMAX) THEN
      Y = ABS(X)
      IF (Y<=1.0_EB) THEN  ! ERFC(X) = 1.0 - ERF(X) FOR -1._EB <= X <= 1.
         IF (Y<SQEPS)  ERFC = 1.0_EB - 2.0_EB*X/SQRTPI
         IF (Y>=SQEPS) ERFC = 1.0_EB - X*(1.0_EB + CSEVL (2._EB*X*X-1._EB, ERFCS, 10) )
      ELSE  ! ERFC(X) = 1.0 - ERF(X) FOR 1._EB < ABS(X) <= XMAX
         Y = Y*Y
         IF (Y<=4._EB) ERFC = EXP(-Y)/ABS(X) * (0.5_EB + CSEVL ((8._EB/Y-5._EB)/3._EB,ERC2CS, 10) )
         IF (Y>4._EB) ERFC = EXP(-Y)/ABS(X) * (0.5_EB + CSEVL (8._EB/Y-1._EB,ERFCCS, 10) )
         IF (X<0._EB) ERFC = 2.0_EB - ERFC
      ENDIF
   ELSE
      ERFC = 0._EB
   ENDIF
ENDIF
RETURN
 
END FUNCTION ERFC
 
 
SUBROUTINE GAUSSJ(A,N,NP,B,M,MP,IERROR)
 
! Solve a linear system of equations with Gauss-Jordon elimination
! Source: Press et al. "Numerical Recipes"
 
INTEGER :: M,MP,N,NP,I,ICOL,IROW,J,K,L,LL,INDXC(NP),INDXR(NP),IPIV(NP)
REAL(EB) :: A(NP,NP),B(NP,MP),BIG,DUM,PIVINV
INTEGER, INTENT(OUT) :: IERROR
 
IERROR = 0
IPIV(1:N) = 0
 
DO I=1,N
   BIG = 0._EB
   DO J=1,N
      IF (IPIV(J)/=1) THEN
         DO K=1,N
            IF (IPIV(K)==0) THEN
               IF (ABS(A(J,K))>=BIG) THEN
                  BIG = ABS(A(J,K))
                  IROW = J
                  ICOL = K
               ENDIF
            ELSE IF (IPIV(K)>1) THEN
               IERROR = 103   ! Singular matrix in gaussj
               RETURN
            ENDIF
         ENDDO
      ENDIF
   ENDDO
   IPIV(ICOL) = IPIV(ICOL) + 1
   IF (IROW/=ICOL) THEN
      DO L=1,N
         DUM = A(IROW,L)
         A(IROW,L) = A(ICOL,L)
         A(ICOL,L) = DUM
      ENDDO
      DO L=1,M
         DUM = B(IROW,L)
         B(IROW,L) = B(ICOL,L)
         B(ICOL,L) = DUM
      ENDDO
   ENDIF
   INDXR(I) = IROW
   INDXC(I) = ICOL
   IF (A(ICOL,ICOL)==0._EB) THEN
      IERROR = 103  ! Singular matrix in gaussj
      RETURN
      ENDIF
   PIVINV = 1._EB/A(ICOL,ICOL)
   A(ICOL,ICOL) = 1.
   A(ICOL,1:N) = A(ICOL,1:N) * PIVINV
   B(ICOL,1:M) = B(ICOL,1:M) * PIVINV
   DO LL=1,N
      IF (LL/=ICOL) THEN
         DUM = A(LL,ICOL)
         A(LL,ICOL) = 0._EB
         A(LL,1:N) = A(LL,1:N) - A(ICOL,1:N)*DUM
         B(LL,1:M) = B(LL,1:M) - B(ICOL,1:M)*DUM
      ENDIF
   ENDDO
ENDDO
DO L=N,1,-1
   IF (INDXR(L)/=INDXC(L)) THEN
      DO K=1,N
         DUM = A(K,INDXR(L))
         A(K,INDXR(L)) = A(K,INDXC(L))
         A(K,INDXC(L)) = DUM
      ENDDO
   ENDIF
ENDDO
 
END SUBROUTINE GAUSSJ
 
 
REAL(EB) FUNCTION CSEVL(X,CS,N)
 
REAL(EB), INTENT(IN) :: X
REAL(EB) CS(:),B1,B0,TWOX,B2
INTEGER NI,N,I
 
B1=0._EB
B0=0._EB
TWOX=2._EB*X
DO I=1,N
B2=B1
B1=B0
NI=N+1-I
B0=TWOX*B1-B2+CS(NI)
ENDDO
 
CSEVL = 0.5_EB*(B0-B2)
 
END FUNCTION CSEVL

INTEGER(2) FUNCTION TWO_BYTE_REAL(REAL_IN)
REAL(FB),INTENT(IN) :: REAL_IN
INTEGER(2) EXP,TEMP,I

IF (ABS(REAL_IN) <= 1.E-17_FB) THEN
   TWO_BYTE_REAL = 0
ELSEIF (ABS(REAL_IN) >= 1.E+16_FB) THEN
   DO I=0,14
      TWO_BYTE_REAL=IBSET(TWO_BYTE_REAL,I)
   ENDDO
ELSE
   EXP = FLOOR(LOG10(ABS(REAL_IN)))+1
   TEMP = ABS(REAL_IN * 10**(-REAL(EXP,FB)+3))
   EXP = EXP + 15
   TWO_BYTE_REAL = EXP * 2**10
   TWO_BYTE_REAL = TWO_BYTE_REAL + TEMP
ENDIF
IF (REAL_IN < 0._FB) TWO_BYTE_REAL = IBSET(TWO_BYTE_REAL,15)

END FUNCTION TWO_BYTE_REAL

INTEGER FUNCTION RLE_COMPRESSION(QIN,NQIN,QMIN,QMAX,COUT)

! Compress the array QIN(1:NQIN) by first mapping to one byte integers and then
! using Run-Length Encoding to convert runs of common integers IIIIIIII TO  #In
! where #=255 is a marker character to distinguish between literal characters 
! and runs of n repeats

INTEGER, INTENT(IN) :: NQIN
REAL, INTENT(IN), DIMENSION(NQIN) :: QIN
REAL, INTENT(IN) :: QMIN, QMAX
CHARACTER(1), DIMENSION(NQIN) :: COUT
CHARACTER(1), PARAMETER :: MARK=CHAR(255)
CHARACTER(1) :: THISCHAR, LASTCHAR
INTEGER :: IIN,IOUT,NREPEATS,IQVAL

IF (QMAX<=QMIN .OR. NQIN<=0) THEN
   RLE_COMPRESSION = 0
   RETURN
ENDIF

IOUT=1
LASTCHAR=MARK

DO IIN = 1, NQIN
   IQVAL = 254*(QIN(IIN) - QMIN)/(QMAX-QMIN)
   IF (IQVAL<0)   IQVAL=0
   IF (IQVAL>254) IQVAL=254
   THISCHAR =CHAR(IQVAL)

   IF (THISCHAR == LASTCHAR) THEN
      NREPEATS = NREPEATS + 1
   ELSE
      NREPEATS = 1
   ENDIF

   IF (NREPEATS>=1 .AND. NREPEATS<=3) THEN
      COUT(IOUT) = THISCHAR
      LASTCHAR=THISCHAR
   ELSEIF (NREPEATS>=4) THEN
      IF (NREPEATS==4) THEN
         IOUT = IOUT - 3
         COUT(IOUT) = MARK
         IOUT = IOUT + 1
         COUT(IOUT) = THISCHAR
         IOUT = IOUT + 1
      ENDIF
      IF (NREPEATS/=4) IOUT = IOUT - 1
      COUT(IOUT) = CHAR(NREPEATS)
      IF (NREPEATS==254) THEN
          NREPEATS=1
          LASTCHAR=MARK
      ENDIF
   ENDIF
   IOUT = IOUT + 1
ENDDO

RLE_COMPRESSION = IOUT - 1

END FUNCTION RLE_COMPRESSION

SUBROUTINE INTERPOLATE1D(X,Y,XI,ANS)
REAL(EB), INTENT(IN), DIMENSION(:) :: X, Y
REAL(EB), INTENT(IN) :: XI
REAL(EB), INTENT(OUT) :: ANS
INTEGER I, UX,LX

UX = UBOUND(X,1)
LX = LBOUND(X,1)

IF (XI <= X(LX)) THEN
  ANS = Y(LX)
ELSEIF (XI >= X(UX)) THEN
  ANS = Y(UX)
ELSE
  L1: DO I=LX,UX-1
    IF (XI -X(I) == 0._EB) THEN
      ANS = Y(I)
      EXIT L1
    ELSEIF (X(I+1)>XI) THEN
      ANS = Y(I)+(XI-X(I))/(X(I+1)-X(I)) * (Y(I+1)-Y(I))
      EXIT L1
    ENDIF
  ENDDO L1
ENDIF

END SUBROUTINE INTERPOLATE1D

END MODULE MATH_FUNCTIONS


MODULE TRAN 
 
! Coordinate transformation functions
 
USE PRECISION_PARAMETERS
IMPLICIT NONE
TYPE TRAN_TYPE
   REAL(EB), POINTER, DIMENSION(:,:) :: C1,C2,C3,CCSTORE,PCSTORE
   INTEGER, POINTER, DIMENSION(:,:) :: IDERIVSTORE
   INTEGER NOC(3),ITRAN(3),NOCMAX
END TYPE TRAN_TYPE
TYPE (TRAN_TYPE), ALLOCATABLE, TARGET, DIMENSION(:) :: TRANS
 
 
CONTAINS
 
 
REAL(EB) FUNCTION G(X,IC,NM)
 
! Coordinate transformation function
 
REAL(EB), INTENT(IN) :: X
INTEGER, INTENT(IN)  :: IC,NM
INTEGER :: I,II,N
TYPE (TRAN_TYPE), POINTER :: T
 
T => TRANS(NM)
 
N = T%NOC(IC)
IF (N==0) THEN
   G = X
   RETURN
ENDIF
 
SELECT CASE(T%ITRAN(IC))
   CASE(1)
      G = 0._EB
      DO I=1,N+1
         G = G + T%C1(I,IC)*X**I
      ENDDO
   CASE(2)
      ILOOP: DO I=1,N+1
         II = I
         IF (X<=T%C1(I,IC)) EXIT ILOOP
      ENDDO ILOOP
      G = T%C2(II-1,IC) + T%C3(II,IC)*(X-T%C1(II-1,IC))
END SELECT
 
END FUNCTION G
 
 
REAL(EB) FUNCTION GP(X,IC,NM)
 
! Derivative of the coordinate transformation function
 
REAL(EB), INTENT(IN) :: X
INTEGER, INTENT(IN)  :: IC,NM
INTEGER :: I,II,N
TYPE (TRAN_TYPE), POINTER :: T
 
T => TRANS(NM)
N =  T%NOC(IC)
IF (N==0) THEN
   GP = 1._EB
   RETURN
ENDIF
 
SELECT CASE(T%ITRAN(IC)) 
   CASE(1)
      GP = 0._EB
      DO I=1,N+1
         GP = GP + I*T%C1(I,IC)*X**(I-1)
      ENDDO
   CASE(2)
      ILOOP: DO I=1,N+1
         II = I
         IF (X<=T%C1(I,IC)) EXIT ILOOP
      ENDDO ILOOP
      GP = T%C3(II,IC)
END SELECT
 
END FUNCTION GP
 
 
REAL(EB) FUNCTION GINV(Z,IC,NM)
 
! Inverse of the coordinate transformation function
 
REAL(EB) :: GF
INTEGER :: N,IT,II,I
REAL(EB), INTENT(IN) :: Z
INTEGER, INTENT(IN)  :: IC,NM
TYPE (TRAN_TYPE), POINTER :: T
 
T => TRANS(NM)
GINV = Z
N = T%NOC(IC)
IF (N==0) RETURN
 
SELECT CASE(T%ITRAN(IC))
   CASE(1)
      LOOP1: DO IT=1,10
         GF = G(GINV,IC,NM)-Z
         IF (ABS(GF)<0.002_EB) EXIT LOOP1
         GINV = GINV - GF/GP(GINV,IC,NM)
      ENDDO LOOP1
   CASE(2)
      ILOOP: DO I=1,N+1
         II = I
         IF (Z<=T%C2(I,IC)) EXIT ILOOP
      ENDDO ILOOP
      GINV = T%C1(II-1,IC) + (Z-T%C2(II-1,IC))/T%C3(II,IC)
END SELECT
 
END FUNCTION GINV
 
 
END MODULE TRAN
