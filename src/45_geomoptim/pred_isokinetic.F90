!{\src2tex{textfont=tt}}
!!****f* ABINIT/pred_isokinetic
!! NAME
!! pred_isokinetic
!!
!! FUNCTION
!! Ionmov predictors (12) Isokinetic ensemble molecular dynamics
!!
!! IONMOV 12:
!! Isokinetic ensemble molecular dynamics.
!! The equation of motion of the ions in contact with a thermostat
!! are solved with the algorithm proposed by Zhang [J. Chem. Phys. 106,
!! 6102 (1997)],
!! as worked out by Minary et al [J. Chem. Phys. 188, 2510 (2003)].
!! The conservation of the kinetic energy is obtained within machine
!! precision, at each step.
!! Related parameters : the time step (dtion), the initial temperature (mdtemp(1)),
!! the final temperature (mdtemp(2)), and the friction coefficient (friction).
!!
!!
!! COPYRIGHT
!! Copyright (C) 1998-2012 ABINIT group (DCA, XG, GMR, JCC, SE)
!! This file is distributed under the terms of the
!! GNU General Public License, see ~abinit/COPYING
!! or http://www.gnu.org/copyleft/gpl.txt .
!! For the initials of contributors,
!! see ~abinit/doc/developers/contributors.txt .
!!
!! INPUTS
!! ab_mover <type(ab_movetype)> : Datatype with all the information
!!                                needed by the preditor
!! itime  : Index of the present iteration
!! ntime  : Maximal number of iterations
!! zDEBUG : if true print some debugging information
!!
!! OUTPUT
!!
!! SIDE EFFECTS
!! hist <type(ab_movehistory)> : History of positions,forces
!!                               acell, rprimd, stresses
!!
!! NOTES
!!
!! PARENTS
!!      mover
!!
!! CHILDREN
!!      hist2var,metric,var2hist,wrtout,xredxcart
!!
!! SOURCE

#if defined HAVE_CONFIG_H
#include "config.h"
#endif

#include "abi_common.h"

subroutine pred_isokinetic(ab_mover,hist,itime,ntime,zDEBUG,iexit)

 use m_profiling

! define dp,sixth,third,etc...
 use defs_basis
! type(ab_movetype), type(ab_movehistory)
 use defs_mover

!This section has been created automatically by the script Abilint (TD).
!Do not modify the following lines by hand.
#undef ABI_FUNC
#define ABI_FUNC 'pred_isokinetic'
 use interfaces_14_hidewrite
 use interfaces_28_numeric_noabirule
 use interfaces_42_geometry
 use interfaces_45_geomoptim, except_this_one => pred_isokinetic
!End of the abilint section

 implicit none

!Arguments ------------------------------------
!scalars
 type(ab_movetype),intent(in)       :: ab_mover
 type(ab_movehistory),intent(inout) :: hist
 integer,intent(in) :: itime
 integer,intent(in) :: ntime
 integer,intent(in) :: iexit
 logical,intent(in) :: zDEBUG

!Local variables-------------------------------
!scalars
 integer  :: ii,jj,kk,iatom,idim,idum=5,nfirst,ifirst
 real(dp) :: ucvol,ucvol0,ucvol_next,a,as,b,sqb,s,s1,s2,scdot,sigma2,vtest,v2gauss,amass_tot
 real(dp),parameter :: v2tol=tol8
 real(dp) :: etotal,rescale_vel
 real(dp) :: favg
 character(len=5000) :: message
!arrays
 real(dp),allocatable,save :: fcart_m(:,:),vel_nexthalf(:,:)

 real(dp) :: acell(3),acell0(3),acell_next(3)
 real(dp) :: rprimd(3,3),rprimd0(3,3),rprim(3,3),rprimd_next(3,3),rprim_next(3,3)
 real(dp) :: gprimd(3,3)
 real(dp) :: gmet(3,3)
 real(dp) :: rmet(3,3)
 real(dp) :: fcart(3,ab_mover%natom)
 real(dp) :: fred(3,ab_mover%natom),fred_corrected(3,ab_mover%natom)
 real(dp) :: xcart(3,ab_mover%natom),xcart_next(3,ab_mover%natom)
 real(dp) :: xred(3,ab_mover%natom),xred_next(3,ab_mover%natom)
 real(dp) :: vel(3,ab_mover%natom)
 real(dp) :: strten(6)

!***************************************************************************
!Beginning of executable session
!***************************************************************************

 if(iexit/=0)then
   if (allocated(fcart_m))       then
     ABI_DEALLOCATE(fcart_m)
   end if
   if (allocated(vel_nexthalf))  then
     ABI_DEALLOCATE(vel_nexthalf)
   end if
   return
 end if

!write(std_out,*) 'isokinetic 01'
!##########################################################
!### 01. Debugging and Verbose

 if(zDEBUG)then
   write(std_out,'(a,3a,40a,37a)') ch10,('-',kk=1,3),&
&   'Debugging and Verbose for pred_isokinetic',('-',kk=1,37)
   write(std_out,*) 'ionmov: ',12
   write(std_out,*) 'itime:  ',itime
 end if

!write(std_out,*) 'isokinetic 02'
!##########################################################
!### 02. Allocate the vectors vin, vout and hessian matrix
!###     These arrays could be allocated from a previus
!###     dataset that exit before itime==ntime

 if(itime==1)then
   if (allocated(fcart_m))       then
     ABI_DEALLOCATE(fcart_m)
   end if
   if (allocated(vel_nexthalf))  then
     ABI_DEALLOCATE(vel_nexthalf)
   end if
 end if

 if (.not.allocated(fcart_m))       then
   ABI_ALLOCATE(fcart_m,(3,ab_mover%natom))
 end if
 if (.not.allocated(vel_nexthalf))  then
   ABI_ALLOCATE(vel_nexthalf,(3,ab_mover%natom))
 end if

!write(std_out,*) 'isokinetic 03'
!##########################################################
!### 03. Obtain the present values from the history

 call hist2var(acell,hist,ab_mover%natom,rprim,rprimd,xcart,xred,zDEBUG)

 fcart(:,:) =hist%histXF(:,:,3,hist%ihist)
 fred(:,:)  =hist%histXF(:,:,4,hist%ihist)
 vel(:,:)   =hist%histV(:,:,hist%ihist)
 strten(:)  =hist%histS(:,hist%ihist)
 etotal     =hist%histE(hist%ihist)

 if(zDEBUG)then
   write (std_out,*) 'fcart:'
   do kk=1,ab_mover%natom
     write (std_out,*) fcart(:,kk)
   end do
   write (std_out,*) 'fred:'
   do kk=1,ab_mover%natom
     write (std_out,*) fred(:,kk)
   end do
   write (std_out,*) 'vel:'
   do kk=1,ab_mover%natom
     write (std_out,*) vel(:,kk)
   end do
   write (std_out,*) 'strten:'
   write (std_out,*) strten(1:3),ch10,strten(4:6)
   write (std_out,*) 'etotal:'
   write (std_out,*) etotal
 end if

 call metric(gmet,gprimd,-1,rmet,rprimd,ucvol)

!Save initial values
 acell0(:)=acell(:)
 rprimd0(:,:)=rprimd(:,:)
 ucvol0=ucvol

!Get rid of mean force on whole unit cell, but only if no
!generalized constraints are in effect
 if(ab_mover%nconeq==0)then
   amass_tot=sum(ab_mover%amass(:)) 
   do ii=1,3
     favg=sum(fred(ii,:))/dble(ab_mover%natom)
!    Note that the masses are used, in order to weight the repartition of the average force. 
!    This procedure is adequate for dynamics, as pointed out by Hichem Dammak (2012 Jan 6)..
     fred_corrected(ii,:)=fred(ii,:)-favg*ab_mover%amass(:)/amass_tot
     if(ab_mover%jellslab/=0.and.ii==3)&
&     fred_corrected(ii,:)=fred(ii,:)
   end do
 else
   fred_corrected(:,:)=fred(:,:)
 end if

!write(std_out,*) 'isokinetic 04'
!##########################################################
!### 04. Second half-velocity (Only after the first itime)

 if(itime>1) then

   do iatom=1,ab_mover%natom
     do idim=1,3
       fcart_m(idim,iatom)=fcart(idim,iatom)/ab_mover%amass(iatom)
     end do
   end do

!  Computation of vel(:,:) at the next positions
!  Computation of v2gauss
   v2gauss=0.0_dp
   do iatom=1,ab_mover%natom
     do idim=1,3
       v2gauss=v2gauss+&
&       vel_nexthalf(idim,iatom)*vel_nexthalf(idim,iatom)*&
&       ab_mover%amass(iatom)
     end do
   end do

!  Calcul de a et b (4.13 de Ref.1)
   a=0.0_dp
   b=0.0_dp
   do iatom=1,ab_mover%natom
     do idim=1,3
       a=a+fcart_m(idim,iatom)*vel_nexthalf(idim,iatom)*ab_mover%amass(iatom)
       b=b+fcart_m(idim,iatom)*fcart_m(idim,iatom)*ab_mover%amass(iatom)
     end do
   end do
   a=a/v2gauss
   b=b/v2gauss


!  Calcul de s et scdot
   sqb=sqrt(b)
   as=sqb*ab_mover%dtion/2.
   s1=cosh(as)
   s2=sinh(as)
   s=a*(s1-1.)/b+s2/sqb
   scdot=a*s2/sqb+s1
   vel(:,:)=(vel_nexthalf(:,:)+fcart_m(:,:)*s)/scdot

   if (zDEBUG)then
     write(std_out,*) 'Computation of the second half-velocity'
     write(std_out,*) 'Cartesian forces per atomic mass (fcart_m):'
     do kk=1,ab_mover%natom
       write (std_out,*) fcart_m(:,kk)
     end do
     write(std_out,*) 'vel:'
     do kk=1,ab_mover%natom
       write (std_out,*) vel(:,kk)
     end do
     write(std_out,*) 'v2gauss:',v2gauss
     write(std_out,*) 'a:',a
     write(std_out,*) 'b:',b
     write(std_out,*) 's:',s
     write(std_out,*) 'scdot:',scdot
   end if

 end if ! (if itime>1)

!write(std_out,*) 'isokinetic 05'
!##########################################################
!### 05. First half-time (First cycle the loop is double)

 if (itime==1) then
   nfirst=2
 else
   nfirst=1
 end if

 do ifirst=1,nfirst

!  Application of Gauss' principle of least constraint according to Fei Zhang's algorithm (J. Chem. Phys. 106, 1997, p.6102)

   acell_next(:)=acell(:)
   ucvol_next=ucvol
   rprim_next(:,:)=rprim(:,:)
   rprimd_next(:,:)=rprimd(:,:)

!  v2gauss is twice the kinetic energy
   v2gauss=0.0_dp
   do iatom=1,ab_mover%natom
     do idim=1,3
       v2gauss=v2gauss+vel(idim,iatom)*vel(idim,iatom)*ab_mover%amass(iatom)
     end do
   end do

!  If there is no kinetic energy
   if (v2gauss<=v2tol.and.itime==1) then
!    Maxwell-Boltzman distribution
     v2gauss=zero
     vtest=zero
     do iatom=1,ab_mover%natom
       do idim=1,3
         vel(idim,iatom)=sqrt(kb_HaK*ab_mover%mdtemp(1)/ab_mover%amass(iatom))*cos(two_pi*uniformrandom(idum))
         vel(idim,iatom)=vel(idim,iatom)*sqrt(-2._dp*log(uniformrandom(idum)))
       end do
     end do

!    Get rid of center-of-mass velocity
     s1=sum(ab_mover%amass(:))
     do idim=1,3
       s2=sum(ab_mover%amass(:)*vel(idim,:))
       vel(idim,:)=vel(idim,:)-s2/s1
     end do

!    Recompute v2gauss
     do iatom=1,ab_mover%natom
       do idim=1,3
         v2gauss=v2gauss+vel(idim,iatom)*vel(idim,iatom)*ab_mover%amass(iatom)
         vtest=vtest+vel(idim,iatom)/(3._dp*ab_mover%natom)
       end do
     end do

!    Now rescale the velocities to give the exact temperature
     rescale_vel=sqrt(3._dp*ab_mover%natom*kb_HaK*ab_mover%mdtemp(1)/v2gauss)
     vel(:,:)=vel(:,:)*rescale_vel

!    Recompute v2gauss with the rescaled velocities
     v2gauss=zero
     do iatom=1,ab_mover%natom
       do idim=1,3
         v2gauss=v2gauss+vel(idim,iatom)*vel(idim,iatom)*ab_mover%amass(iatom)
       end do
     end do

!    Compute the variance and print
     sigma2=(v2gauss/(3._dp*ab_mover%natom)-ab_mover%amass(1)*vtest**2)/kb_HaK

   end if

   do iatom=1,ab_mover%natom
     do idim=1,3
       fcart_m(idim,iatom)=fcart(idim,iatom)/ab_mover%amass(iatom)
     end do
   end do

   if (zDEBUG)then
     write(std_out,*) 'Calculation first half-velocity '
     write (std_out,*) 'vel:'
     do kk=1,ab_mover%natom
       write (std_out,*) vel(:,kk)
     end do
     write (std_out,*) 'xcart:'
     do kk=1,ab_mover%natom
       write (std_out,*) xcart(:,kk)
     end do
     write (std_out,*) 'xred:'
     do kk=1,ab_mover%natom
       write (std_out,*) xred(:,kk)
     end do
     write (std_out,*) 'fcart_m'
     do kk=1,ab_mover%natom
       write (std_out,*) fcart_m(:,kk)
     end do
     write(std_out,*) 's2',s2
     write(std_out,*) 'v2gauss',v2gauss
     write(std_out,*) 'sigma2',sigma2

     write(message, '(a)' )&
&     ' --- Rescaling or initializing velocities to initial temperature'
     call wrtout(std_out,message,'COLL')
     write(message, '(a,d12.5,a,D12.5)' )&
&     ' --- Scaling factor :',rescale_vel,' Asked T (K) ',ab_mover%mdtemp(1)
     call wrtout(std_out,message,'COLL')
     write(message, '(a,d12.5,a,D12.5)' )&
&     ' --- Effective temperature',v2gauss/(3*ab_mover%natom*kb_HaK),' From variance', sigma2
     call wrtout(std_out,message,'COLL')
   end if

!  Convert input xred (reduced coordinates) to xcart (cartesian)
   call xredxcart(ab_mover%natom,1,rprimd,xcart,xred)

   if(itime==1.and.ifirst==1) then
     write(std_out,*) 'if itime==1'
     vel_nexthalf(:,:)=vel(:,:)
     xcart_next(:,:)=xcart(:,:)
     call xredxcart(ab_mover%natom,-1,rprimd,xcart_next,xred_next)
     xred=xred_next
     call xredxcart(ab_mover%natom,1,rprimd,xcart,xred)
   end if

 end do

!Computation of vel_nexthalf (4.16 de Ref.1)
!Computation of a and b (4.13 de Ref.1)
 a=0.0_dp
 b=0.0_dp
 do iatom=1,ab_mover%natom
   do idim=1,3
     a=a+fcart_m(idim,iatom)*vel(idim,iatom)*ab_mover%amass(iatom)
     b=b+fcart_m(idim,iatom)*fcart_m(idim,iatom)*ab_mover%amass(iatom)
   end do
 end do
 a=a/v2gauss
 b=b/v2gauss
!Computation of s and scdot
 sqb=sqrt(b)
 as=sqb*ab_mover%dtion/2.
 s1=cosh(as)
 s2=sinh(as)
 s=a*(s1-1.)/b+s2/sqb
 scdot=a*s2/sqb+s1

 vel_nexthalf(:,:)=(vel(:,:)+fcart_m(:,:)*s)/scdot

!Computation of the next positions
 xcart_next(:,:)=xcart(:,:)+vel_nexthalf(:,:)*ab_mover%dtion

 if (zDEBUG)then
   write(std_out,*) 'a:',a
   write(std_out,*) 'b:',b
   write(std_out,*) 's:',s
   write(std_out,*) 'scdot:',scdot
 end if

!Convert back to xred (reduced coordinates)
 call xredxcart(ab_mover%natom,-1,rprimd,xcart_next,xred_next)

!write(std_out,*) 'isokinetic 06'
!##########################################################
!### 06. Update the history with the prediction

 xcart=xcart_next
 xred=xred_next

!Increase indexes
 hist%ihist=hist%ihist+1

!Compute rprimd from rprim and acell
 do kk=1,3
   do jj=1,3
     rprimd(jj,kk)=rprim(jj,kk)*acell(jj)
   end do
 end do

!Compute xcart from xred, and rprimd
 call xredxcart(ab_mover%natom,1,rprimd,xcart,xred)

!Fill the history with the variables
!xcart, xred, acell, rprimd
 call var2hist(acell,hist,ab_mover%natom,rprim,rprimd,xcart,xred,zDEBUG)

 if(zDEBUG)then
   write (std_out,*) 'fcart:'
   do kk=1,ab_mover%natom
     write (std_out,*) fcart(:,kk)
   end do
   write (std_out,*) 'fred:'
   do kk=1,ab_mover%natom
     write (std_out,*) fred(:,kk)
   end do
   write (std_out,*) 'vel:'
   do kk=1,ab_mover%natom
     write (std_out,*) vel(:,kk)
   end do
   write (std_out,*) 'strten:'
   write (std_out,*) strten(1:3),ch10,strten(4:6)
   write (std_out,*) 'etotal:'
   write (std_out,*) etotal
 end if

 hist%histV(:,:,hist%ihist)=vel(:,:)
 hist%histT(hist%ihist)=itime*ab_mover%dtion

!write(std_out,*) 'isokinetic 07'
!##########################################################
!### 07. Deallocate in the last iteration
!###     When itime==ntime the predictor will be no called

!Temporarily deactivated (MT sept. 2011)
 if (.false.) write(std_out,*) ntime
!if(itime==ntime-1)then
!if (allocated(fcart_m))      deallocate(fcart_m)
!if (allocated(vel_nexthalf)) deallocate(vel_nexthalf)
!end if

end subroutine pred_isokinetic
!!***
