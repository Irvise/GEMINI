module interpolation
use phys_consts, only: wp
implicit none

contains

pure real(wp) function interp1(x1,f,x1i)

!------------------------------------------------------------
!-------A 1D LINEAR INTERPOLATION FUNCTION.  THE INDEPENDENT
!-------VARIABLE FOR THE GIVEN DATA GRID MUST BE MONOTONICALLY
!-------INCREASING, BUT THE LOCATIONS FOR THE INTERPOLATION DATA
!-------CAN BE IN ANY ORDER.  NOTE THAT EXTRAPOLATION IS NOT DONE
!-------AT ALL BY THIS FUNCTION - VALUES OUTSIDE DOMAIN OF
!-------ORIGINAL DATA ARE SIMPLY SET TO ZERO.
!------------------------------------------------------------

real(wp), dimension(:), intent(in) :: x1,f, x1i
dimension :: interp1(1:size(x1i,1))

integer :: lx1,lx1i,ix1,ix1i
real(wp) :: slope

integer :: ix10,ix1fin


lx1=size(x1,1)
lx1i=size(x1i,1)

do ix1i=1,lx1i
!      !find the 'bin' for this point; i.e. find ix1 s.t. xi(ix1i) is between x(ix1-1) and x(ix1)
  ix10=1
  ix1=lx1/2
  ix1fin=lx1
  if (x1i(ix1i)>=x1(1) .and. x1i(ix1i)<=x1(lx1)) then    !in bounds
    do while(.not.(x1i(ix1i)>=x1(ix1-1) .and. x1i(ix1i)<=x1(ix1)))    !keep going until we are in the interval we want
      if (x1i(ix1i)>=x1(ix10) .and. x1i(ix1i)<=x1(ix1)) then    !left half (correct guess)
        ix1fin=ix1
      else    !wrong take the "right" half (har har)
        ix10=ix1
      end if
      ix1=(ix1fin+ix10)/2
      if (ix10==ix1) then
        ix1=lx1
      end if
    end do
  else if (x1i(ix1i)<x1(1)) then
    ix1=1
  else
    ix1=lx1
  end if



  !execute interpolation for this point
  if (ix1>1 .and. ix1<=lx1) then   !interpolation
    slope=(f(ix1)-f(ix1-1))/(x1(ix1)-x1(ix1-1))
    interp1(ix1i)=f(ix1-1)+slope*(x1i(ix1i)-x1(ix1-1))
  else
    interp1(ix1i)=0
  end if
end do


!THERE IS SOME ISSUE WITH POINTS OUTSIDE INTERPOLANT DOMAIN - THIS IS A
!WORKAROUND UNTIL I CAN PIN DOWN THE EXACT PROBLEM
do ix1i=1,lx1i
  if(x1i(ix1i)<x1(1) .or. x1i(ix1i)>x1(lx1)) then
    interp1(ix1i)=0
  end if
end do

end function interp1


pure real(wp) function interp2(x1,x2,f,x1i,x2i)

!------------------------------------------------------------
!-------A 2D BILINEAR INTERPOLATION FUNCTION.  THIS VERSION ASSUMES
!-------THAT THE LIST OF OUTPUT POINTS IS A 'FLAT LIST' RATHER THAN
!-------DESCRIPTIVE OF A 2D MESHGRID.
!------------------------------------------------------------

real(wp), dimension(:), intent(in) :: x1, x2, x1i, x2i
real(wp), dimension(:,:), intent(in) :: f
dimension :: interp2(1:size(x1i,1))


real(wp) :: fx1ix2prev, fx1ix2next    !function estimates at x1i point  vs. at x2 interfaces
real(wp) :: slope

integer :: lx1,lx2,lxi,ix1,ix2,ixi
integer :: ix10,ix1fin,ix20,ix2fin



lx1=size(x1,1)
lx2=size(x2,1)
lxi=size(x1i,1)    !only one size since this a flat list of grid points


do ixi=1,lxi
  !find the x1 'bin' for this point; i.e. find ix1 s.t. xi(ix1i) is between x(ix1-1) and x(ix1)
  ix10=1
  ix1=lx1/2
  ix1fin=lx1
  if (x1i(ixi)>=x1(1) .and. x1i(ixi)<=x1(lx1)) then    !in bounds
    do while(.not.(x1i(ixi)>=x1(ix1-1) .and. x1i(ixi)<=x1(ix1)))    !keep going until we are in the interval we want
      if (x1i(ixi)>=x1(ix10) .and. x1i(ixi)<=x1(ix1)) then    !left half (correct guess)
        ix1fin=ix1
      else    !wrong take the "right" half (har har)
        ix10=ix1
      end if
      ix1=(ix1fin+ix10)/2
      if (ix10==ix1) then
        ix1=lx1
      end if
    end do
  else if (x1i(ixi)<x1(1)) then
    ix1=1
  else
    ix1=lx1
  end if


  !find the x2 'bin' for this point; i.e. find ix2 s.t. x2i(ix2i) is between x2(ix2-1) and x2(ix2)
  ix20=1
  ix2=lx2/2
  ix2fin=lx2
  if (x2i(ixi)>=x2(1) .and. x2i(ixi)<=x2(lx2)) then    !in bounds
    do while(.not.(x2i(ixi)>=x2(ix2-1) .and. x2i(ixi)<=x2(ix2)))    !keep going until we are in the interval we want
      if (x2i(ixi)>=x2(ix20) .and. x2i(ixi)<=x2(ix2)) then    !left half (correct guess)
        ix2fin=ix2
      else    !wrong take the "right" half (har har)
        ix20=ix2
      end if
      ix2=(ix2fin+ix20)/2
      if (ix20==ix2) then
        ix2=lx2
      end if
    end do
  else if (x2i(ixi)<x2(1)) then
    ix2=1
  else
    ix2=lx2
  end if


  !execute interpolations in x1 for fixed values of x2 at this point
  if (ix1>1 .and. ix1<=lx1 .and. ix2>1 .and. ix2<=lx2) then   !interpolation
    !first the "prev" x2 value
    slope=(f(ix1,ix2-1)-f(ix1-1,ix2-1))/(x1(ix1)-x1(ix1-1))
    fx1ix2prev=f(ix1-1,ix2-1)+slope*(x1i(ixi)-x1(ix1-1))

    !now the "next" x2 value
    slope=(f(ix1,ix2)-f(ix1-1,ix2))/(x1(ix1)-x1(ix1-1))
    fx1ix2next=f(ix1-1,ix2)+slope*(x1i(ixi)-x1(ix1-1))

    !finally an interpolation in x2 to finish things off
    slope=(fx1ix2next-fx1ix2prev)/(x2(ix2)-x2(ix2-1))
    interp2(ixi)=fx1ix2prev+slope*(x2i(ixi)-x2(ix2-1))
  else
    interp2(ixi)=0
  end if
end do


!THERE IS SOME ISSUE WITH POINTS OUTSIDE INTERPOLANT DOMAIN - THIS IS A WORKAROUND UNTIL I CAN PIN DOWN THE EXACT PROBLEM
do ixi=1,lxi
if(x1i(ixi)<x1(1) .or. x1i(ixi)>x1(lx1) .or. x2i(ixi)<x2(1) .or. x2i(ixi)>x2(lx2)) then
  interp2(ixi)=0
end if
end do

end function interp2


pure real(wp) function interp3(x1,x2,x3,f,x1i,x2i,x3i)

!------------------------------------------------------------
!-------A 2D BILINEAR INTERPOLATION FUNCTION.  THIS VERSION ASSUMES
!-------THAT THE LIST OF OUTPUT POINTS IS A 'FLAT LIST' RATHER THAN
!-------DESCRIPTIVE OF A 2D MESHGRID.
!------------------------------------------------------------

real(wp), dimension(:), intent(in) :: x1,x2,x3,x1i,x2i,x3i
real(wp), dimension(:,:,:), intent(in) :: f
dimension :: interp3(1:size(x1i,1))     !interpolated points are a flat list

real(wp) :: fx1ix2pix3p,fx1ix2nix3p,fx1ix2pix3n,fx1ix2nix3n    !function estimates at x1i point  vs. at x2 interfaces
real(wp) :: fx2ix3p,fx2ix3n
real(wp) :: slope                     !temp value for slope for interpolations

integer :: lx1,lx2,lx3,lxi,ix1,ix2,ix3,ixi
integer :: ix10,ix1fin,ix20,ix2fin,ix30,ix3fin



lx1=size(x1,1)
lx2=size(x2,1)
lx3=size(x3,1)
lxi=size(x1i,1)    !only one size since this a flat list of grid points


do ixi=1,lxi
  !find the x1 'bin' for this point; i.e. find ix1 s.t. xi(ix1i) is between x(ix1-1) and x(ix1)
  ix10=1
  ix1=lx1/2
  ix1fin=lx1
  if (x1i(ixi)>=x1(1) .and. x1i(ixi)<=x1(lx1)) then    !in bounds
    do while(.not.(x1i(ixi)>=x1(ix1-1) .and. x1i(ixi)<=x1(ix1)))    !keep going until we are in the interval we want
      if (x1i(ixi)>=x1(ix10) .and. x1i(ixi)<=x1(ix1)) then    !left half (correct guess)
        ix1fin=ix1
      else    !wrong take the "right" half (har har)
        ix10=ix1
      end if
      ix1=(ix1fin+ix10)/2
      if (ix10==ix1) then
        ix1=lx1
      end if
    end do
  else if (x1i(ixi)<x1(1)) then
    ix1=1
  else
    ix1=lx1
  end if


  !find the x2 'bin' for this point; i.e. find ix2 s.t. x2i(ix2i) is between x2(ix2-1) and x2(ix2)
  ix20=1
  ix2=lx2/2
  ix2fin=lx2
  if (x2i(ixi)>=x2(1) .and. x2i(ixi)<=x2(lx2)) then    !in bounds
    do while(.not.(x2i(ixi)>=x2(ix2-1) .and. x2i(ixi)<=x2(ix2)))    !keep going until we are in the interval we want
      if (x2i(ixi)>=x2(ix20) .and. x2i(ixi)<=x2(ix2)) then    !left half (correct guess)
        ix2fin=ix2
      else    !wrong take the "right" half (har har)
        ix20=ix2
      end if
      ix2=(ix2fin+ix20)/2
      if (ix20==ix2) then
        ix2=lx2
      end if
    end do
  else if (x2i(ixi)<x2(1)) then
    ix2=1
  else
    ix2=lx2
  end if


  !find the x3 'bin' for this point; i.e. find ix3 s.t. x3i(ix3i) is between x3(ix3-1) and x3(ix3)
  ix30=1
  ix3=lx3/2
  ix3fin=lx3
  if (x3i(ixi)>=x3(1) .and. x3i(ixi)<=x3(lx3)) then    !in bounds
    do while(.not.(x3i(ixi)>=x3(ix3-1) .and. x3i(ixi)<=x3(ix3)))    !keep going until we are in the interval we want
      if (x3i(ixi)>=x3(ix30) .and. x3i(ixi)<=x3(ix3)) then    !left half (correct guess)
        ix3fin=ix3
      else    !wrong take the "right" half (har har)
        ix30=ix3
      end if
      ix3=(ix3fin+ix30)/2
      if (ix30==ix3) then
        ix3=lx3
      end if
    end do
  else if (x3i(ixi)<x3(1)) then
    ix3=1
  else
    ix3=lx3
  end if


  if (ix1>1 .and. ix1<=lx1 .and. ix2>1 .and. ix2<=lx2 .and. ix3>1 .and. ix3<=lx3) then   !interpolation
    !interpolate x1 for fixed values of x2,x3 (four separate interps)
    !first the "prev" x2 value, "prev" x2 value
    slope=(f(ix1,ix2-1,ix3-1)-f(ix1-1,ix2-1,ix3-1))/(x1(ix1)-x1(ix1-1))
    fx1ix2pix3p=f(ix1-1,ix2-1,ix3-1)+slope*(x1i(ixi)-x1(ix1-1))

    !now the "next" x2 value, "prev" x3
    slope=(f(ix1,ix2,ix3-1)-f(ix1-1,ix2,ix3-1))/(x1(ix1)-x1(ix1-1))
    fx1ix2nix3p=f(ix1-1,ix2,ix3-1)+slope*(x1i(ixi)-x1(ix1-1))

    !prev x2, next x3
    slope=(f(ix1,ix2-1,ix3)-f(ix1-1,ix2-1,ix3))/(x1(ix1)-x1(ix1-1))
    fx1ix2pix3n=f(ix1-1,ix2-1,ix3)+slope*(x1i(ixi)-x1(ix1-1))

    !next x3, next x3
    slope=(f(ix1,ix2,ix3)-f(ix1-1,ix2,ix3))/(x1(ix1)-x1(ix1-1))
    fx1ix2nix3n=f(ix1-1,ix2,ix3)+slope*(x1i(ixi)-x1(ix1-1))


    !interpolate between each x2 value (two separate interps)
    !interp in x2 for the x3 prev points
    slope=(fx1ix2nix3p-fx1ix2pix3p)/(x2(ix2)-x2(ix2-1))
    fx2ix3p=fx1ix2pix3p+slope*(x2i(ixi)-x2(ix2-1))

    !interp in 2 for the next x3 points
    slope=(fx1ix2nix3n-fx1ix2pix3n)/(x2(ix2)-x2(ix2-1))
    fx2ix3n=fx1ix2pix3n+slope*(x2i(ixi)-x2(ix2-1))


    !finally an interpolation in x2 to finish things off (single interp)
    slope=(fx2ix3n-fx2ix3p)/(x3(ix3)-x3(ix3-1))
    interp3(ixi)=fx2ix3p+slope*(x3i(ixi)-x3(ix3-1))
  else
    interp3(ixi)=0._wp
  end if
end do


!THERE IS SOME ISSUE WITH POINTS OUTSIDE INTERPOLANT DOMAIN - THIS IS A WORKAROUND UNTIL I CAN PIN DOWN THE EXACT PROBLEM
do ixi=1,lxi
if(x1i(ixi)<x1(1) .or. x1i(ixi)>x1(lx1) .or. x2i(ixi)<x2(1) .or. x2i(ixi)>x2(lx2) .or. x3i(ixi)<x3(1) .or. &
   x3i(ixi)>x3(lx3) .or. lx1==1 .or. lx2==1 .or. lx3==1) then     !also cover the case where there is a singleton dimension...
  interp3(ixi)=0._wp
end if
end do

end function interp3


pure real(wp) function interp2_plaid(x1,x2,f,x1i,x2i)

!------------------------------------------------------------
!-------A 2D BILINEAR INTERPOLATION FUNCTION.  THIS VERSION ASSUMES
!-------A PLAID INTERPRETATION OF THE OUTPUT POINTS (I.E. THAT THEY
!-------FORM A 2D MESHGRID RATHER THAN A FLAT LIST OF POINTS.
!-------
!-------MZ - this may not be used at all anymore, but kept
!-------for potential future use???
!------------------------------------------------------------

real(wp), dimension(:), intent(in) :: x1, x2, x1i, x2i
real(wp), dimension(:,:), intent(in) :: f
dimension :: interp2_plaid(1:size(x1i,1),1:size(x2i,1))

real(wp) :: fx1ix2prev, fx1ix2next    !function estimates at x1i point  vs. at x2 interfaces
real(wp) :: slope

integer :: lx1,lx2,lx1i,lx2i,ix1,ix2,ix1i,ix2i
real(wp), dimension(1:size(x1i)) :: slicex1i
real(wp), dimension(1:size(x2i)) :: slicex2i


lx1=size(x1,1)
lx2=size(x2,1)
lx1i=size(x1i,1)
lx2i=size(x2i,1)


do ix2i=1,lx2i
  do ix1i=1,lx1i
    !find the x1 'bin' for this point; i.e. find ix1 s.t. xi(ix1i) is between x(ix1-1) and x(ix1)
    ix1=1
    do while(x1i(ix1i)>x1(ix1) .and. ix1<=lx1)
      ix1=ix1+1
    end do


    !find the x2 'bin' for this point; i.e. find ix2 s.t. x2i(ix2i) is between x2(ix2-1) and x2(ix2)
    ix2=1
    do while(x2i(ix2i)>x2(ix2) .and. ix2<=lx2)
      ix2=ix2+1
    end do


    !execute interpolations in x1 for fixed values of x2 at this point
    if (ix1>1 .and. ix1<=lx1 .and. ix2>1 .and. ix2<=lx2) then   !interpolation
      !first the "prev" x2 value
      slope=(f(ix1,ix2-1)-f(ix1-1,ix2-1))/(x1(ix1)-x1(ix1-1))
      fx1ix2prev=f(ix1-1,ix2-1)+slope*(x1i(ix1i)-x1(ix1-1))

      !now the "next" x2 value
      slope=(f(ix1,ix2)-f(ix1-1,ix2))/(x1(ix1)-x1(ix1-1))
      fx1ix2next=f(ix1-1,ix2)+slope*(x1i(ix1i)-x1(ix1-1))

      !finally an interpolation in x2 to finish things off
      slope=(fx1ix2next-fx1ix2prev)/(x2(ix2)-x2(ix2-1))
      interp2_plaid(ix1i,ix2i)=fx1ix2prev+slope*(x2i(ix2i)-x2(ix2-1))
    else
      interp2_plaid(ix1i,ix2i)=0
    end if
  end do
end do

end function interp2_plaid

end module interpolation
