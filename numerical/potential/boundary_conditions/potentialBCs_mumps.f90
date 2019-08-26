module potentialBCs_mumps

use mpi, only: mpi_integer, mpi_comm_world, mpi_status_ignore

use phys_consts, only: wp, pi, Re, debug
use grid, only: curvmesh, lx1, lx2, lx2all, lx3all, gridflag
use interpolation, only : interp1,interp2
use timeutils, only : dateinc, date_filename

implicit none
private

!ALL OF THE FOLLOWING MODULE-SCOPE ARRAYS ARE USED FOR INTERPOLATING PRECIPITATION INPUT FILES (IF USED)
!It should be noted that all of these will eventually be fullgrid variables since only root does this...
real(wp), dimension(:), allocatable :: mlonp
real(wp), dimension(:), allocatable :: mlatp    !coordinates of electric field data
integer :: llon,llat

real(wp), dimension(:,:), allocatable :: E0xp,E0yp    !x (lon.) and y (lat.) components of the electric field
real(wp), dimension(:,:), allocatable :: Vminx1p,Vmaxx1p
real(wp), dimension(:), allocatable :: Vminx2pslice,Vmaxx2pslice    !only slices because field lines (x1-dimension) should be equipotentials
real(wp), dimension(:), allocatable :: Vminx3pslice,Vmaxx3pslice
real(wp), dimension(:), allocatable :: Edatp    !needed when a 1D interpolation is to be done, i.e. when there is 1D sourde data

real(wp), dimension(:), allocatable :: mloni    !flat list of mlat,mlon locations on grid that we need to interpolate onto
real(wp), dimension(:), allocatable :: mlati

real(wp), dimension(:,:), allocatable :: E0xiprev,E0xinext,E0yiprev,E0yinext    !fields interpolated spatially
real(wp), dimension(:,:), allocatable :: Vminx1iprev,Vminx1inext,Vmaxx1iprev,Vmaxx1inext
real(wp), dimension(:), allocatable :: Vminx2isprev,Vminx2isnext,Vmaxx2isprev,Vmaxx2isnext
real(wp), dimension(:), allocatable :: Vminx3isprev,Vminx3isnext,Vmaxx3isprev,Vmaxx3isnext

integer, dimension(3) :: ymdprev,ymdnext   !dates for interpolated data
real(wp) :: UTsecprev,UTsecnext
real(wp) :: tprev,tnext

real(wp) :: flagdirich_double

integer :: ix1ref,ix2ref,ix3ref     !reference locaiton along field line closest to reference point of input data (300 km alt. at the grid center)

public :: potentialbcs2D, potentialbcs2D_fileinput, clear_potential_fileinput

contains


subroutine potentialBCs2D_fileinput(dt,dtE0,t,ymd,UTsec,E0dir,&
                                  x,Vminx1,Vmaxx1,Vminx2,Vmaxx2,Vminx3, &
                                  Vmaxx3,E01all,E02all,E03all,flagdirich)

!A FILE INPUT BASED BOUNDARY CONDITIONS FOR ELECTRIC POTENTIAL OR
!FIELD-ALIGNED CURRENT.  NOTE THAT THIS IS ONLY CALLED BY THE ROOT
!PROCESS!!!

real(wp), intent(in) :: dt
real(wp), intent(in) :: dtE0    !cadence at which we are reading in the E0 files
real(wp), intent(in) :: t
integer, dimension(3), intent(in) :: ymd    !date for which we wish to calculate perturbations
real(wp), intent(in) :: UTsec
character(*), intent(in) :: E0dir       !directory where data are kept

type(curvmesh), intent(in) :: x

real(wp), dimension(:,:), intent(out), target :: Vminx1,Vmaxx1
real(wp), dimension(:,:), intent(out) :: Vminx2,Vmaxx2
real(wp), dimension(:,:), intent(out) :: Vminx3,Vmaxx3
real(wp), dimension(:,:,:), intent(out) :: E01all,E02all,E03all
integer, intent(out) :: flagdirich

character(:), allocatable :: fn1, fn2, fn3
integer :: inunit

real(wp) :: UTsectmp
integer, dimension(3) :: ymdtmp

real(wp), dimension(lx2all*lx3all) :: parami
real(wp), dimension(lx2all,lx3all) :: parami2D
real(wp), dimension(lx2all) :: parami2    !interpolated parameter with size of lx2
real(wp), dimension(lx3all) :: parami3
real(wp), dimension(lx2all,lx3all) :: E0xinow,E0yinow,Vminx1inow,Vmaxx1inow
real(wp), dimension(lx3all) :: Vminx2isnow,Vmaxx2isnow
real(wp), dimension(lx2all) :: Vminx3isnow,Vmaxx3isnow
real(wp) :: slope

integer :: ix1,ix2,ix3,iid,iflat,ios    !grid sizes are borrowed from grid module
real(wp) :: h2ref,h3ref


!COMPUTE SOURCE/FORCING TERMS FROM BACKGROUND FIELDS, ETC.
E01all = 0.    !do not allow a background parallel field


!FILE INPUT FOR THE PERPENDICULAR COMPONENTS OF THE ELECTRIC FIELD (ZONAL - X2, MERIDIONAL - X3)
if(t + dt / 2._wp >= tnext) then    !need to load a new file
  if ( .not. allocated(mlonp)) then    !need to read in the grid data from input file
    ymdprev=ymd
    UTsecprev=UTsec
    ymdnext=ymdprev
    UTsecnext=UTsecprev

    fn1 = E0dir // '/simsize.dat'
    if (debug) print *, 'Inputting electric field data size from file:  ',fn1
    open(newunit=inunit,file=fn1,status='old',form='unformatted',access='stream')
    read(inunit) llon,llat
    close(inunit)
    if (debug) print *, 'Electric field data has llon,llat size:  ',llon,llat
    allocate(mlonp(llon),mlatp(llat))    !bit of code duplication with worker code block below...


    !IF WE HAVE SINGLETON DIMENSION THEN ALLOCATE SOME SPACE FOR A TEMP
    !ARRAY FOR INPUTTING INTO INTERP1
    if (llon==1) then
      allocate(Edatp(llat))
    elseif (llat==1) then
      allocate(Edatp(llon))
    end if


    !NOW READ THE GRID
    fn2 = E0dir // '/simgrid.dat'
    if (debug) print *, 'Inputting electric field grid from file:  ',fn2
    open(newunit=inunit,file=fn2,status='old',form='unformatted',access='stream')
    read(inunit) mlonp,mlatp
    close(inunit)
    if (debug) print *, 'Electric field data has mlon,mlat extent:', &
              minval(mlonp(:)), maxval(mlonp(:)), minval(mlatp(:)), maxval(mlatp(:))

    !SPACE TO STORE INPUT DATA
    allocate(E0xp(llon,llat),E0yp(llon,llat))
    allocate(Vminx1p(llon,llat),Vmaxx1p(llon,llat))
    allocate(Vminx2pslice(llat),Vmaxx2pslice(llat))
    allocate(Vminx3pslice(llon),Vmaxx3pslice(llon))
    allocate(E0xiprev(lx2all,lx3all),E0xinext(lx2all,lx3all),E0yiprev(lx2all,lx3all),E0yinext(lx2all,lx3all))
    allocate(Vminx1iprev(lx2all,lx3all),Vminx1inext(lx2all,lx3all), &
             Vmaxx1iprev(lx2all,lx3all),Vmaxx1inext(lx2all,lx3all), &
             Vminx2isprev(lx3all),Vminx2isnext(lx3all),Vmaxx2isprev(lx3all),Vmaxx2isnext(lx3all), &
             Vminx3isprev(lx2all),Vminx3isnext(lx2all),Vmaxx3isprev(lx2all),Vmaxx3isnext(lx2all))

    E0xiprev=0d0; E0yiprev=0d0; E0xinext=0d0; E0yinext=0d0;     !these need to be initialized so that something sensible happens at the beginning
    Vminx1iprev=0d0; Vmaxx1iprev=0d0; Vminx1inext=0d0; Vmaxx1inext=0d0;
    Vminx2isprev=0d0; Vmaxx2isprev=0d0; Vminx2isnext=0d0; Vmaxx2isnext=0d0;
    Vminx3isprev=0d0; Vmaxx3isprev=0d0; Vminx3isnext=0d0; Vmaxx3isnext=0d0;


    !ALL PROCESSES NEED TO DEFINE THE POINTS THAT THEY WILL BE INTERPOLATING ONTO
    if (lx2all > 1) then ! 3D sim
      ix2ref = lx2all/2      !note integer division
    else
      ix2ref = 1
    endif
    ix3ref=lx3all/3

    ix1ref=minloc(abs(x%rall(:,ix2ref,ix3ref)-Re-300d3),1)    !by default the code uses 300km altitude as a reference location, using the center x2,x3 point
    allocate(mloni(lx2all*lx3all),mlati(lx2all*lx3all))
    do ix3=1,lx3all
      do ix2=1,lx2all
        iflat=(ix3-1)*lx2all+ix2
        !mlati(iflat)=90d0-x%thetaall(lx1,ix2,ix3)*180d0/pi
        !mloni(iflat)=x%phiall(lx1,ix2,ix3)*180d0/pi
        mlati(iflat)=90d0-x%thetaall(ix1ref,ix2,ix3)*180d0/pi
        mloni(iflat)=x%phiall(ix1ref,ix2,ix3)*180d0/pi
      end do
    end do
    if (debug) print *, 'Grid has mlon,mlat range:  ',minval(mloni),maxval(mloni),minval(mlati),maxval(mlati)
    if (debug) print *, 'Grid has size:  ',iflat
  end if


  !GRID INFORMATION EXISTS AT THIS POINT SO START READING IN PRECIP DATA
  !read in the data from file
  if (debug) print *,'tprev,tnow,tnext:  ',tprev,t+dt/2d0,tnext
  ymdtmp=ymdnext
  UTsectmp=UTsecnext
  call dateinc(dtE0,ymdtmp,UTsectmp)    !get the date for "next" params
  fn3=date_filename(E0dir,ymdtmp,UTsectmp)     !form the standard data filename
  if (debug) print *, 'Pulling electric field data from file:  ',fn3
  open(newunit=inunit, file=fn3, status='old',form='unformatted',access='stream',iostat=ios)
  if (ios/=0) error stop 'Bad input file, cannot proceed'  ! per MZ Oct. 2018
  !just set everything to zero
  !print *, 'Bad input file, setting everything to some default value...'
  !flagdirich=1    !to short-circuit solve...
  !E0xp=0d0; E0yp=0d0; Vminx1p=0d0; Vmaxx1p=0d0;
  !Vminx2pslice=0d0; Vmaxx2pslice=0d0; Vminx3pslice=0d0; Vmaxx3pslice=0d0;

  read(inunit) flagdirich_double
  read(inunit) E0xp,E0yp
  read(inunit) Vminx1p,Vmaxx1p    !background fields and top/bottom boundar conditions
  read(inunit) Vminx2pslice,Vmaxx2pslice    !these ohly used for 3D simulations
  read(inunit) Vminx3pslice,Vmaxx3pslice
  close(inunit)

  if (debug) then
  print *, 'Min/max values for E0xp:  ',minval(E0xp),maxval(E0xp)
  print *, 'Min/max values for E0yp:  ',minval(E0yp),maxval(E0yp)
  print *, 'Min/max values for Vminx1p:  ',minval(Vminx1p),maxval(Vminx1p)
  print *, 'Min/max values for Vmaxx1p:  ',minval(Vmaxx1p),maxval(Vmaxx1p)
  print *, 'Min/max values for Vminx2pslice:  ',minval(Vminx2pslice),maxval(Vminx2pslice)
  print *, 'Min/max values for Vmaxx2pslice:  ',minval(Vmaxx2pslice),maxval(Vmaxx2pslice)
  print *, 'Min/max values for Vminx3pslice:  ',minval(Vminx3pslice),maxval(Vminx3pslice)
  print *, 'Min/max values for Vmaxx3pslice:  ',minval(Vmaxx3pslice),maxval(Vmaxx3pslice)
  endif

  !ALL WORKERS DO SPATIAL INTERPOLATION TO THEIR SPECIFIC GRID SITES
  if (debug) print *, 'Initiating electric field boundary condition spatial interpolations for date:  ',ymdtmp,' ',UTsectmp
  if (llon==1) then    !source data has singleton dimension in longitude
    if (debug) print *, 'Singleton longitude dimension detected; interpolating in latitude...'
    Edatp=E0xp(1,:)
    parami=interp1(mlatp,Edatp,mlati)   !will work even for 2D grids, just repeats the data in the lon direction
    E0xiprev=E0xinext
    E0xinext=reshape(parami,[lx2all,lx3all])

    Edatp=E0yp(1,:)
    parami=interp1(mlatp,Edatp,mlati)
    E0yiprev=E0yinext
    E0yinext=reshape(parami,[lx2all,lx3all])

    Edatp=Vminx1p(1,:)          !both min and max need to be read in from file and interpolated
    parami=interp1(mlatp,Edatp,mlati)
    Vminx1iprev=Vminx1inext
    Vminx1inext=reshape(parami,[lx2all,lx3all])

    Edatp=Vmaxx1p(1,:)
    parami=interp1(mlatp,Edatp,mlati)
    Vmaxx1iprev=Vmaxx1inext
    Vmaxx1inext=reshape(parami,[lx2all,lx3all])

    !note that for 2D simulations we don't use Vmaxx2p, etc. data read in from the input file - these BC's will be set later
  elseif (llat==1) then
    if (debug) print *, 'Singleton latitude dimension detected; interpolating in longitude...'
    Edatp=E0xp(:,1)
    parami=interp1(mlonp,Edatp,mloni)
    E0xiprev=E0xinext
    E0xinext=reshape(parami,[lx2all,lx3all])

    Edatp=E0yp(:,1)
    parami=interp1(mlonp,Edatp,mloni)
    E0yiprev=E0yinext
    E0yinext=reshape(parami,[lx2all,lx3all])

    Edatp=Vminx1p(:,1)
    parami=interp1(mlonp,Edatp,mloni)
    Vminx1iprev=Vminx1inext
    Vminx1inext=reshape(parami,[lx2all,lx3all])

    Edatp=Vmaxx1p(:,1)
    parami=interp1(mlonp,Edatp,mloni)
    Vmaxx1iprev=Vmaxx1inext
    Vmaxx1inext=reshape(parami,[lx2all,lx3all])
  else    !source data is 2D
    if (debug) print *, 'Executing full lat/lon interpolation...'
    parami=interp2(mlonp,mlatp,E0xp,mloni,mlati)     !interp to temp var.
    E0xiprev=E0xinext                       !save new pervious
    E0xinext=reshape(parami,[lx2all,lx3all])    !overwrite next with new interpolated input

    parami=interp2(mlonp,mlatp,E0yp,mloni,mlati)
    E0yiprev=E0yinext
    E0yinext=reshape(parami,[lx2all,lx3all])

    parami=interp2(mlonp,mlatp,Vminx1p,mloni,mlati)
    Vminx1iprev=Vminx1inext
    Vminx1inext=reshape(parami,[lx2all,lx3all])

    parami=interp2(mlonp,mlatp,Vmaxx1p,mloni,mlati)
    Vmaxx1iprev=Vmaxx1inext
    Vmaxx1inext=reshape(parami,[lx2all,lx3all])

    !We need to interpolate the lateral boundaries in the direction of mlat
    parami=interp1(mlatp,Vminx2pslice,mlati)    !note mlati is a flat list of grid point lats, so need to reshape it
    Vminx2isprev=Vminx2isnext
    parami2D=reshape(parami,[lx2all,lx3all])
    parami3=parami2D(1,:)      !data should be constant across mlon, i.e. we're hoping the grid is plaid in mlat and mlon, otherwise not sure what to do here
    Vminx2isnext=parami3

    parami=interp1(mlatp,Vmaxx2pslice,mlati)
    Vmaxx2isprev=Vmaxx2isnext
    parami2D=reshape(parami,[lx2all,lx3all])
    parami3=parami2D(1,:)      !data should be constant across mlon...
    Vmaxx2isnext=parami3

    !now lateral interpolation in mlon
    parami=interp1(mlonp,Vminx3pslice,mloni)
    Vminx3isprev=Vminx3isnext
    parami2D=reshape(parami,[lx2all,lx3all])
    parami2=parami2D(:,1)
    Vminx3isnext=parami2

    parami=interp1(mlonp,Vmaxx3pslice,mloni)
    Vmaxx3isprev=Vmaxx3isnext
    parami2D=reshape(parami,[lx2all,lx3all])
    parami2=parami2D(:,1)
    Vmaxx3isnext=parami2
  end if

  if (debug) then
  print *, 'Min/max values for E0xi:  ',minval(E0xinext),maxval(E0xinext)
  print *, 'Min/max values for E0yi:  ',minval(E0yinext),maxval(E0yinext)
  print *, 'Min/max values for Vminx1i:  ',minval(Vminx1inext),maxval(Vminx1inext)
  print *, 'Min/max values for Vmaxx1i:  ',minval(Vmaxx1inext),maxval(Vmaxx1inext)

  if (llon/=1 .and. llat/=1) then
    print *, 'Min/max values for Vminx2i:  ',minval(Vminx2isnext),maxval(Vminx2isnext)
    print *, 'Min/max values for Vmaxx2i:  ',minval(Vmaxx2isnext),maxval(Vmaxx2isnext)
    print *, 'Min/max values for Vminx3i:  ',minval(Vminx3isnext),maxval(Vminx3isnext)
    print *, 'Min/max values for Vmaxx3i:  ',minval(Vmaxx3isnext),maxval(Vmaxx3isnext)
  end if
  endif


  !UPDATE OUR CONCEPT OF PREVIOUS AND NEXT TIMES
  tprev=tnext
  UTsecprev=UTsecnext
  ymdprev=ymdnext

  tnext=tprev+dtE0
  UTsecnext=UTsectmp
  ymdnext=ymdtmp
end if


!INTERPOLATE IN TIME (LINEAR)
flagdirich=int(flagdirich_double,4)     !make sure to set solve type every time step, as it does not persiste between function calls
if (debug) print *, 'Solve type: ',flagdirich
do ix3=1,lx3all
  do ix2=1,lx2all
    slope=(E0xinext(ix2,ix3)-E0xiprev(ix2,ix3))/(tnext-tprev)
    E0xinow(ix2,ix3)=E0xiprev(ix2,ix3)+slope*(t+dt/2d0-tprev)

    slope=(E0yinext(ix2,ix3)-E0yiprev(ix2,ix3))/(tnext-tprev)
    E0yinow(ix2,ix3)=E0yiprev(ix2,ix3)+slope*(t+dt/2d0-tprev)

    slope=(Vminx1inext(ix2,ix3)-Vminx1iprev(ix2,ix3))/(tnext-tprev)
    Vminx1inow(ix2,ix3)=Vminx1iprev(ix2,ix3)+slope*(t+dt/2d0-tprev)

    slope=(Vmaxx1inext(ix2,ix3)-Vmaxx1iprev(ix2,ix3))/(tnext-tprev)
    Vmaxx1inow(ix2,ix3)=Vmaxx1iprev(ix2,ix3)+slope*(t+dt/2d0-tprev)
  end do
end do
if (lx2all/=1 .and. lx3all/=1) then     !full 3D grid need to also handle lateral boundaries
  do ix3=1,lx3all
    slope=(Vminx2isnext(ix3)-Vminx2isprev(ix3))/(tnext-tprev)
    Vminx2isnow(ix3)=Vminx2isprev(ix3)+slope*(t+dt/2-tprev)

    slope=(Vmaxx2isnext(ix3)-Vmaxx2isprev(ix3))/(tnext-tprev)
    Vmaxx2isnow(ix3)=Vmaxx2isprev(ix3)+slope*(t+dt/2-tprev)
  end do
  do ix2=1,lx2all
    slope=(Vminx3isnext(ix2)-Vminx3isprev(ix2))/(tnext-tprev)
    Vminx3isnow(ix2)=Vminx3isprev(ix2)+slope*(t+dt/2-tprev)

    slope=(Vmaxx3isnext(ix2)-Vmaxx3isprev(ix2))/(tnext-tprev)
    Vmaxx3isnow(ix2)=Vmaxx3isprev(ix2)+slope*(t+dt/2-tprev)
  end do
end if


!SOME BASIC DIAGNOSTICS
if(debug) then
print *, 'tprev,t,tnext:  ',tprev,t+dt/2d0,tnext
  print *, 'Min/max values for E0xinow:  ',minval(E0xinow),maxval(E0xinow)
  print *, 'Min/max values for E0yinow:  ',minval(E0yinow),maxval(E0yinow)
  print *, 'Min/max values for Vminx1inow:  ',minval(Vminx1inow),maxval(Vminx1inow)
  print *, 'Min/max values for Vmaxx1inow:  ',minval(Vmaxx1inow),maxval(Vmaxx1inow)

  if (llon/=1 .and. llat/=1) then
    print *, 'Min/max values for Vminx2inow:  ',minval(Vminx2isnow),maxval(Vminx2isnow)
    print *, 'Min/max values for Vmaxx2inow:  ',minval(Vmaxx2isnow),maxval(Vmaxx2isnow)
    print *, 'Min/max values for Vminx3inow:  ',minval(Vminx3isnow),maxval(Vminx3isnow)
    print *, 'Min/max values for Vmaxx3inow:  ',minval(Vmaxx3isnow),maxval(Vmaxx3isnow)
  end if
endif

!LOAD POTENTIAL SOLVER INPUT ARRAYS, FIRST MAP THE ELECTRIC FIELDS
do ix3=1,lx3all
  do ix2=1,lx2all
    h2ref=x%h2all(ix1ref,ix2,ix3)    !define a reference metric factor for a given field line
    h3ref=x%h3all(ix1ref,ix2,ix3)
    do ix1=1,lx1
      E02all(ix1,ix2,ix3)=E0xinow(ix2,ix3)*h2ref/x%h2all(ix1,ix2,ix3)
      E03all(ix1,ix2,ix3)=E0yinow(ix2,ix3)*h3ref/x%h3all(ix1,ix2,ix3)
    end do
  end do
end do


!NOW THE BOUNDARY CONDITIONS
do ix3=1,lx3all
  do ix2=1,lx2all
    Vminx1(ix2,ix3)=Vminx1inow(ix2,ix3)
    Vmaxx1(ix2,ix3)=Vmaxx1inow(ix2,ix3)
  end do
end do


!SET REMAINING BOUNDARY CONDITIONS BASED ON WHAT THE TOP IS.  IF WE HAVE A
!3D GRID THE SIDES ARE GROUNDED AUTOMATICALLY, WHEREAS FOR 2D THEY ARE SET
!TO TOP VALUE  IF DIRICHLET AND TO TOP VALUE IF DIRICHLET.
if (lx2all/=1 .and. lx3all/=1) then     !full 3D grid
!      Vminx2=0d0    !This actualy needs to be different for KHI
!      Vmaxx2=0d0
!      Vminx3=0d0
!      Vmaxx3=0d0
  do ix3=1,lx3all
    do ix1=1,lx1
      Vminx2(ix1,ix3)=Vminx2isnow(ix3)
      Vmaxx2(ix1,ix3)=Vmaxx2isnow(ix3)
    end do
  end do

  do ix2=1,lx2all
    do ix1=1,lx1
      Vminx3(ix1,ix2)=Vminx3isnow(ix2)
      Vmaxx3(ix1,ix2)=Vmaxx3isnow(ix2)
    end do
  end do
else    !some type of 2D grid, lateral boundary will be overwritten
  Vminx2=0d0
  Vmaxx2=0d0
  if (flagdirich==1) then    !Dirichlet:  needs to be the same as the top corner grid points
    do ix1=1,lx1
      Vminx3(ix1,:)=Vmaxx1(:,1)
      Vmaxx3(ix1,:)=Vmaxx1(:,lx3all)
    end do
  else    !Neumann in x1:  sides are grounded...
    Vminx3=0d0
    Vmaxx3=0d0
  end if
end if

end subroutine potentialBCs2D_fileinput


subroutine clear_potential_fileinput()

if(allocated(mlonp)) then
  deallocate(mlonp,mlatp,mloni,mlati,E0xp,E0yp,Vminx1p,Vmaxx1p)
  deallocate(Vminx2pslice,Vmaxx2pslice)
  deallocate(Vminx3pslice,Vmaxx3pslice)
  if (allocated(Edatp)) then
    deallocate(Edatp)
  end if
  deallocate(E0xiprev,E0xinext,E0yiprev,E0yinext)
  deallocate(Vminx1iprev,Vminx1inext,Vmaxx1iprev,Vmaxx1inext)
  deallocate(Vminx2isprev,Vminx2isnext,Vmaxx2isprev,Vmaxx2isnext)
  deallocate(Vminx3isprev,Vminx3isnext,Vmaxx3isprev,Vmaxx3isnext)
end if

end subroutine clear_potential_fileinput


subroutine potentialBCs2D(t,x,Vminx1,Vmaxx1,Vminx2,Vmaxx2,Vminx3, &
                                      Vmaxx3,E01all,E02all,E03all,flagdirich)

!THIS IS A SIMPLE GAUSSIAN POTENTIAL PERTURBATION (IN X1,X2,X3 SPAE)

real(wp), intent(in) :: t
type(curvmesh), intent(in) :: x

real(wp), dimension(:,:), intent(out), target :: Vminx1,Vmaxx1
real(wp), dimension(:,:), intent(out) :: Vminx2,Vmaxx2
real(wp), dimension(:,:), intent(out) :: Vminx3,Vmaxx3
real(wp), dimension(:,:,:), intent(out) :: E01all,E02all,E03all
integer, intent(out) :: flagdirich

real(wp), dimension(1:size(Vmaxx1,1),1:size(Vmaxx1,2)) :: Emaxx1    !pseudo-electric field

real(wp) :: Phipk
integer :: ix1,ix2,ix3    !grid sizes are borrow from grid module
integer :: im
!    integer, parameter :: lmodes=8
real(wp) :: phase
real(wp), dimension(1:size(Vmaxx1,1)) :: x3dev
real(wp) :: meanx2,sigx2,meanx3,sigx3,meant,sigt,sigcurv,x30amp,varc    !for setting background field

real(wp), dimension(:,:), pointer :: Vtopalt,Vbotalt


!CALCULATE/SET TOP BOUNDARY CONDITIONS
sigx2=1d0/20d0*(x%x2all(lx2all)-x%x2all(1))
meanx2=0.5d0*(x%x2all(1)+x%x2all(lx2all))
sigx3=1d0/20d0*(x%x3all(lx3all)-x%x3all(1))    !this requires that all workers have a copy of x3all!!!!
meanx3=0.5d0*(x%x3all(1)+x%x3all(lx3all))

if (gridflag/=2) then
  Vtopalt=>Vminx1
  Vbotalt=>Vmaxx1
else
  Vtopalt=>Vmaxx1
  Vbotalt=>Vminx1
end if

Phipk=0d0      !pk current density
flagdirich=0    !Neumann conditions
do ix3=1,lx3all
  do ix2=1,lx2all
    Vtopalt(ix2,ix3)=0d0
  end do
end do


!SOME USER INFO
if (debug) print *, 'At time:  ',t,'  Max FAC set to be:  ',maxval(abs(Vtopalt))


!BOTTOM BOUNDARY IS ALWAYS ZERO CURRENT - SIDES ARE JUST GROUNDED
Vbotalt=0d0   !since we need to have no current through bottom boundary
Vminx2=0d0
Vmaxx2=0d0
Vminx3=0d0
Vmaxx3=0d0


!COMPUTE SOURCE/FORCING TERMS FROM BACKGROUND FIELDS, ETC.
E01all=0d0
E02all=0d0
E03all=0d0

end subroutine potentialBCs2D


end module potentialBCs_mumps
