!{\src2tex{textfont=tt}}
!!****f* ABINIT/loop3dte
!! NAME
!! loop3dte
!!
!! FUNCTION
!! Loop over the perturbations j1, j2 and j3
!!
!! COPYRIGHT
!! Copyright (C) 2002-2012 ABINIT group (MVeithen,MB)
!! This file is distributed under the terms of the
!! GNU General Public License, see ~abinit/COPYING
!! or http://www.gnu.org/copyleft/gpl.txt .
!! For the initials of contributors, see ~abinit/doc/developers/contributors.txt .
!!
!! INPUTS
!!  cg(2,mpw*nspinor*mband*mkmem*nsppol) = array for planewave
!!                                          coefficients of wavefunctions
!!  cgindex(nkpt,nsppol) = for each k-point, cgindex tores the location
!!                         of the WF in the cg array
!!  dtfil <type(datafiles_type)>=variables related to files
!!  dtset <type(dataset_type)>=all input variables for this dataset
!!  etotal = new total energy (no meaning at output)
!!  gmet(3,3)=reciprocal space metric tensor in bohr**-2
!!  gprimd(3,3)=dimensional primitive translations for reciprocal space(bohr^-1)
!!  gsqcut=Fourier cutoff on G^2 for "large sphere" of radius double
!!   that of the basis sphere--appropriate for charge density rho(G),
!!   Hartree potential, and pseudopotentials
!!  ------ Removed in beautification because unused MS -----
!!  gsqcut_eff=Fourier cutoff on G^2 for "large sphere" of radius double
!!    that of the basis sphere--appropriate for charge density rho(G),
!!    Hartree potential, and pseudopotentials, corresponding to ecut_eff
!!  --------------------------------------------------------
!!  kg(3,mpw*mkmem)=reduced planewave coordinates
!!  kneigh(30,nkpt) = index of the neighbours of each k-point
!!  kg_neigh(30,nkpt,3) = necessary to construct the vector joining a k-point
!!                         to its nearest neighbour in case of a single k-point,
!!                         a line of k-points or a plane of k-points.
!!  kptindex(2,nkpt3)= index of the k-points in the reduced BZ
!!                     related to a k-point in the full BZ
!!  kpt3(3,nkpt3) = reduced coordinates of k-points in the full BZ
!!  kxc(nfft,nkxc)=exchange-correlation kernel
!!  k3xc(nfft,nk3xc)=third-order exchange-correlation kernel
!!  mband = maximum number of bands
!!  mgfft = maximum single fft dimension
!!  mkmem = maximum number of k points which can fit in core memory
!!  mkmem_max = maximal number of k-points on each processor (MPI //)
!!  mk1mem = maximum number of k points for first-order WF
!!           which can fit in core memory
!!  mpert =maximum number of ipert
!!  mpi_enreg=MPI-parallelisation information
!!  mpw   = maximum number of planewaves in basis sphere (large number)
!!  mvwtk(30,nkpt) = weights to compute the finite difference ddk
!!  natom = number of atoms in unit cell
!!  nfft  = (effective) number of FFT grid points (for this processor)
!!  nkpt  = number of k points
!!  nkpt3 = number of k-points in the full BZ
!!  nkxc=second dimension of the array kxc, see rhohxc.f for a description
!!  nneigh  = total number of neighbours required to evaluate the finite
!!          difference formula
!!  nspinor = number of spinorial components of the wavefunctions
!!  nsppol = number of channels for spin-polarization (1 or 2)
!!  npwarr(nkpt) = array holding npw for each k point
!!  occ(mband*nkpt*nsppol) = occupation number for each band and k
!!  psps <type(pseudopotential_type)> = variables related to pseudopotentials
!!  pwind(mpw,nneigh,mkmem) = array used to compute the overlap matrix smat
!!                           between k-points
!!  rfpert(3,mpert,3,mpert,3,mpert) = array defining the type of perturbations
!!       that have to be computed
!!       1   ->   element has to be computed explicitely
!!      -1   ->   use symmetry operations to obtain the corresponding element
!!  rmet(3,3)=real space metric (bohr**2)
!!  rprimd(3,3)=dimensional primitive translations (bohr)
!!  ucvol = unit cell volume (bohr^3)
!!  xred(3,natom) = reduced atomic coordinates
!!
!! OUTPUT
!!  blkflg(3,mpert,3,mpert) = flags for each element of the 3DTE
!!                             (=1 if computed)
!!  d3lo(2,3,mpert,3,mpert,3,mpert) = matrix of the 3DTEs
!!
!! SIDE EFFECTS
!!  hdr <type(hdr_type)>=the header of wf, den and pot files
!!
!! NOTES
!!
!! TODO
!!
!! PARENTS
!!      nonlinear
!!
!! CHILDREN
!!      appdig,dotprod_vn,fourdp,getph,hartre,initylmg,inwffil,ioarr,mkcor3
!!      mkvxc3,mv_3dte,resp3dte,status,timab,vloca3,wffclose,wrtout
!!
!! SOURCE

#if defined HAVE_CONFIG_H
#include "config.h"
#endif

#include "abi_common.h"


subroutine loop3dte(blkflg,cg,cgindex,dtfil,dtset,d3lo,&
& etotal,gmet,gprimd,gsqcut, & !gsqcut_eff
& hdr,kg,kneigh,kg_neigh,kptindex,kpt3,kxc,k3xc,mband,mgfft,mkmem,mkmem_max,mk1mem,&
& mpert,mpi_enreg,mpw,mvwtk,natom,nfft,nkpt,nkpt3,nkxc,nk3xc,nneigh,nspinor,nsppol,&
& npwarr,occ,psps,pwind,&
& rfpert,rmet,rprimd,ucvol,xred)

 use m_profiling

 use defs_basis
 use defs_datatypes
 use m_wffile
 use defs_abitypes
 use defs_wvltypes

!This section has been created automatically by the script Abilint (TD).
!Do not modify the following lines by hand.
#undef ABI_FUNC
#define ABI_FUNC 'loop3dte'
 use interfaces_14_hidewrite
 use interfaces_18_timing
 use interfaces_32_util
 use interfaces_53_ffts
 use interfaces_53_spacepar
 use interfaces_56_recipspace
 use interfaces_56_xc
 use interfaces_59_io_mpi
 use interfaces_62_iowfdenpot
 use interfaces_72_response
 use interfaces_79_seqpar_mpi
!End of the abilint section

 implicit none

!Arguments ------------------------------------
!scalars
 integer,intent(in) :: mband,mgfft,mk1mem,mkmem,mkmem_max,mpert,mpw,natom,nfft
 integer,intent(in) :: nk3xc,nkpt,nkpt3,nkxc,nneigh,nspinor,nsppol
 real(dp),intent(in) :: gsqcut,ucvol !,gsqcut_eff
 real(dp),intent(inout) :: etotal
 type(MPI_type),intent(inout) :: mpi_enreg
 type(datafiles_type),intent(in) :: dtfil
 type(dataset_type),intent(inout) :: dtset
 type(hdr_type),intent(inout) :: hdr
 type(pseudopotential_type),intent(in) :: psps
!arrays
 integer,intent(in) :: cgindex(nkpt,nsppol),kg(3,mk1mem*mpw),kneigh(30,nkpt)
 integer,intent(in) :: kg_neigh(30,nkpt,3)
 integer,intent(in) :: kptindex(2,nkpt3),npwarr(nkpt),pwind(mpw,nneigh,mkmem)
 integer,intent(in) :: rfpert(3,mpert,3,mpert,3,mpert)
 integer,intent(out) :: blkflg(3,mpert,3,mpert,3,mpert)
 real(dp),intent(in) :: cg(2,mpw*nspinor*mband*mkmem*nsppol),gmet(3,3)
 real(dp),intent(in) :: gprimd(3,3),k3xc(nfft,nk3xc),kpt3(3,nkpt3)
 real(dp),intent(in) :: kxc(nfft,nkxc),mvwtk(30,nkpt),rmet(3,3),rprimd(3,3)
 real(dp),intent(in) :: xred(3,natom)
 real(dp),intent(inout) :: occ(mband*nkpt*nsppol)
 real(dp),intent(out) :: d3lo(2,3,mpert,3,mpert,3,mpert)

!Local variables-------------------------------
!scalars
 integer,parameter :: level=51
 integer :: accessfil,ask_accurate,counter,cplex,fform,fformr=52,formeig,i1dir
 integer :: i1pert,i2dir,i2pert,i3dir,i3pert,iatom,ierr,iexit,ifft,index,ir
 integer :: ireadwf,itypat,mcg,mpsang,n1,n2,n3,n3xccc,nfftot,nspden,option,optorth
 integer :: pert1case,pert2case,pert3case,rdwr,rdwrpaw,timrev
 real(dp) :: ecut_eff,exc3,valuei
 character(len=500) :: message
 character(len=fnlen) :: fiden1i,fiwf1i,fiwf3i
 type(wffile_type) :: wff1,wff2,wfft1,wfft2
 type(wvl_data) :: wvl
!arrays
 integer,allocatable :: atindx(:),atindx1(:),nattyp(:)
 real(dp) :: d3_berry(2,3),tsec(2),ylmgr_dum(1)
 real(dp),allocatable :: cg1(:,:),cg3(:,:),eigen1(:),ph1d(:,:),rho1r1(:,:)
 real(dp),allocatable :: rho2g1(:,:),rho2r1(:,:),rho3r1(:,:),vhartr1(:)
 real(dp),allocatable :: vpsp1(:),vtrial1(:,:),vxc1(:,:),work(:),xc_tmp(:,:)
 real(dp),allocatable :: xccc3d1(:),xccc3d2(:),xccc3d3(:),ylm(:,:,:)
 type(pawrhoij_type),allocatable :: rhoij_dum(:)

! ***********************************************************************

!DEBUG
!write(std_out,*)'loop3dte: enter'
!stop
!ENDDEBUG




 call timab(502,1,tsec)
 call status(0,dtfil%filstat,iexit,level,'enter         ')

!
!If dtset%accesswff == 2 set all array outputs to netcdf format
!
 accessfil = 0
 if (dtset%accesswff == IO_MODE_NETCDF) then
   accessfil = 1
 end if
 if (dtset%accesswff == IO_MODE_ETSF) then
   accessfil = 3
 end if

 timrev = 1
 cplex = 2 - timrev
 nspden = dtset%nspden
 ecut_eff = (dtset%ecut)*(dtset%dilatmx)**2
 mpsang = psps%mpsang
 optorth=1;if (psps%usepaw==1) optorth=0

 ABI_ALLOCATE(cg1,(2,dtset%mpw*dtset%nspinor*mband*dtset%mk1mem*dtset%nsppol))
 ABI_ALLOCATE(cg3,(2,dtset%mpw*dtset%nspinor*mband*dtset%mk1mem*dtset%nsppol))
 ABI_ALLOCATE(eigen1,(2*dtset%mband*dtset%mband*dtset%nkpt*dtset%nsppol))
 ABI_ALLOCATE(rho1r1,(cplex*nfft,dtset%nspden))
 ABI_ALLOCATE(rho2r1,(cplex*nfft,dtset%nspden))
 ABI_ALLOCATE(rho2g1,(2,nfft))
 ABI_ALLOCATE(rho3r1,(cplex*nfft,dtset%nspden))
 ABI_ALLOCATE(ylm,(2,dtset%mpw*dtset%mkmem,mpsang*mpsang*psps%useylm))

 ask_accurate=1 ; formeig = 1 ; fform = 2 ; ireadwf = 1
 n1=dtset%ngfft(1) ; n2=dtset%ngfft(2) ; n3=dtset%ngfft(3)
 nfftot=n1*n2*n3





!Generate an index table of atoms, in order for them to be used
!type after type.
 ABI_ALLOCATE(atindx,(natom))
 ABI_ALLOCATE(atindx1,(natom))
 ABI_ALLOCATE(nattyp,(psps%ntypat))
 index=1
 do itypat=1,psps%ntypat
   nattyp(itypat)=0
   do iatom=1,natom
     if(dtset%typat(iatom)==itypat)then
       atindx(iatom)=index
       atindx1(index)=iatom
       index=index+1
       nattyp(itypat)=nattyp(itypat)+1
     end if
   end do
 end do

!Generate the 1-dimensional phases
 ABI_ALLOCATE(ph1d,(2,3*(2*mgfft+1)*natom))
 call getph(atindx,natom,n1,n2,n3,ph1d,xred)

!Set up the Ylm for each k point
 if (psps%useylm==1) then
   if(mkmem==0) open(dtfil%unylm,file=dtfil%fnametmp_ylm,form='unformatted',status='unknown')
   call status(0,dtfil%filstat,iexit,level,'call initylmg ')
   call initylmg(gprimd,kg,dtset%kptns,dtset%mkmem,mpi_enreg,psps%mpsang,&
&   dtset%mpw,dtset%nband,dtset%nkpt,&
&   npwarr,dtset%nsppol,0,rprimd,dtfil%unkg,dtfil%unylm,ylm,ylmgr_dum)
 end if


 ABI_ALLOCATE(vpsp1,(cplex*nfft))
 ABI_ALLOCATE(xccc3d1,(cplex*nfft))
 ABI_ALLOCATE(xccc3d2,(cplex*nfft))
 ABI_ALLOCATE(xccc3d3,(cplex*nfft))

 ABI_ALLOCATE(vhartr1,(cplex*nfft))
 ABI_ALLOCATE(vxc1,(cplex*nfft,dtset%nspden))
 ABI_ALLOCATE(vtrial1,(cplex*nfft,dtset%nspden))

!Loop over the perturbations j1, j2, j3

 pert1case = 0 ; pert2case = 0 ; pert3case = 0

 do i1pert = 1, mpert
   do i1dir = 1, 3

     if ((maxval(rfpert(i1dir,i1pert,:,:,:,:))==1)) then

       pert1case = i1dir + (i1pert-1)*3
       counter = pert1case
       call appdig(pert1case,dtfil%fnamewff1,fiwf1i)

       call status(counter,dtfil%filstat,iexit,level,'call inwffil  ')

       mcg=mpw*nspinor*mband*mkmem*nsppol
       call inwffil(ask_accurate,cg1,dtset,dtset%ecut,ecut_eff,eigen1,dtset%exchn2n3d,&
&       formeig,gmet,hdr,&
&       ireadwf,dtset%istwfk,kg,dtset%kptns,dtset%localrdwf,&
&       dtset%mband,mcg,dtset%mk1mem,mpi_enreg,mpw,&
&       dtset%nband,dtset%ngfft,dtset%nkpt,npwarr,&
&       dtset%nsppol,dtset%nsym,&
&       occ,optorth,rprimd,&
&       dtset%symafm,dtset%symrel,dtset%tnons,&
&       dtfil%unkg1,wff1,wfft1,dtfil%unwff1,dtfil%unwft1,fiwf1i,dtfil%fnametmp_1wf1,wvl)

       if (ireadwf==1) then
         call WffClose (wff1,ierr)
       end if

       rho1r1(:,:) = 0._dp
       if (dtset%get1den /= 0 .or. dtset%ird1den /= 0) then
         rdwr=1;rdwrpaw=0
         call appdig(pert1case,dtfil%fildens1in,fiden1i)
         call status(counter,dtfil%filstat,iexit,level,'call ioarr    ')
         call ioarr(accessfil,rho1r1,dtset, etotal,fformr,fiden1i,hdr,mpi_enreg, &
&         cplex*nfft,rhoij_dum,rdwr,rdwrpaw,wvl%descr)
       end if

       xccc3d1(:) = 0._dp
       if ((psps%n1xccc/=0).and.(i1pert <= natom)) then
         call status(counter,dtfil%filstat,iexit,level,'call mkcor3   ')
         call mkcor3(cplex,i1dir,i1pert,natom,psps%ntypat,n1,psps%n1xccc,&
&         n2,n3,dtset%qptn,rprimd,dtset%typat,ucvol,&
&         psps%xcccrc,psps%xccc1d,xccc3d1,xred)
       end if ! psps%n1xccc/=0





       do i3pert = 1, mpert
         do i3dir = 1, 3

           if ((maxval(rfpert(i1dir,i1pert,:,:,i3dir,i3pert))==1)) then

             pert3case = i3dir + (i3pert-1)*3
             counter = 100*pert3case + pert1case
             call appdig(pert3case,dtfil%fnamewff1,fiwf3i)

             call status(counter,dtfil%filstat,iexit,level,'call inwffil  ')
             mcg=mpw*nspinor*mband*mkmem*nsppol
             call inwffil(ask_accurate,cg3,dtset,dtset%ecut,ecut_eff,eigen1,dtset%exchn2n3d,&
&             formeig,gmet,hdr,&
&             ireadwf,dtset%istwfk,kg,dtset%kptns,dtset%localrdwf,&
&             dtset%mband,mcg,dtset%mk1mem,mpi_enreg,mpw,&
&             dtset%nband,dtset%ngfft,dtset%nkpt,npwarr,&
&             dtset%nsppol,dtset%nsym,&
&             occ,optorth,rprimd,&
&             dtset%symafm,dtset%symrel,dtset%tnons,&
&             dtfil%unkg1,wff2,wfft2,dtfil%unwff2,dtfil%unwft2,&
&             fiwf3i,dtfil%fnametmp_1wf2,wvl)
             if (ireadwf==1) then
               call WffClose (wff2,ierr)
             end if

             rho3r1(:,:) = 0._dp
             if (dtset%get1den /= 0 .or. dtset%ird1den /= 0) then
               rdwr=1;rdwrpaw=0
               call appdig(pert3case,dtfil%fildens1in,fiden1i)
               call status(counter,dtfil%filstat,iexit,level,'call ioarr    ')
               call ioarr(accessfil,rho3r1, dtset, etotal,fformr,fiden1i,hdr, mpi_enreg, &
&               cplex*nfft,rhoij_dum,rdwr,rdwrpaw,wvl%descr)
             end if

             xccc3d3(:) = 0._dp
             if ((psps%n1xccc/=0).and.(i3pert <= natom)) then
               call status(counter,dtfil%filstat,iexit,level,'call mkcor3   ')
               call mkcor3(cplex,i3dir,i3pert,natom,psps%ntypat,n1,psps%n1xccc,&
&               n2,n3,dtset%qptn,rprimd,dtset%typat,ucvol,&
&               psps%xcccrc,psps%xccc1d,xccc3d3,xred)
             end if ! psps%n1xccc/=0




             do i2pert = 1, mpert

!              In case of electric field perturbation, evaluate the ddk
!              using the finite difference expression of
!              Marzari and Vanderbilt PRB 56, 12847 (1997).

               d3_berry(:,:) = 0._dp

               if ((i2pert==dtset%natom+2).and.&
&               (maxval(rfpert(i1dir,i1pert,:,i2pert,i3dir,i3pert)) == 1)) then

                 call timab(511,1,tsec)
                 call status(counter,dtfil%filstat,iexit,level,'call mv_3dte  ')
                 call mv_3dte(cg,cgindex,cg1,cg3,dtset,dtfil,d3_berry,gmet,&
&                 i1pert,i3pert,i1dir,i3dir,&
&                 kneigh,kg_neigh,kptindex,kpt3,mband,mkmem,mkmem_max,mk1mem,&
&                 mpi_enreg,mpw,mvwtk,natom,nkpt,nkpt3,nneigh,npwarr,nspinor,nsppol,pwind)
                 call timab(511,2,tsec)

               end if

               if (mpi_enreg%me == 0) then

                 if(sum(rfpert(i1dir,i1pert,:,i2pert,i3dir,i3pert))>0)then

                   write(message,'(a,a,a,a,a,a)')ch10,ch10,&
&                   ' Decomposition of the third-order energy for the set of perturbations',ch10
                   call wrtout(std_out,message,'COLL')
                   call wrtout(ab_out,message,'COLL')

                   if (i1pert < natom + 1) then
                     write(message,'(a,i3,a,i3)') &
&                     ' j1 : displacement of atom ',i1pert,' along direction ', i1dir
                   end if
                   if (i1pert == dtset%natom + 2) then
                     write(message,'(a,i4)')' j1 : homogeneous electric field along direction ',i1dir
                   end if
                   call wrtout(std_out,message,'COLL')
                   call wrtout(ab_out,message,'COLL')

                   if (i3pert < natom + 1) then
                     write(message,'(a,i3,a,i3,a)') &
&                     ' j3 : displacement of atom ',i3pert,' along direction ', i3dir,ch10
                   end if
                   if (i3pert == dtset%natom + 2) then
                     write(message,'(a,i4,a)')' j3 : homogeneous electric field along direction ',i3dir,ch10
                   end if
                   call wrtout(std_out,message,'COLL')
                   call wrtout(ab_out,message,'COLL')

                 end if

               end if ! mpi_enreg%me == 0

               do i2dir = 1, 3

                 if (rfpert(i1dir,i1pert,i2dir,i2pert,i3dir,i3pert)==1) then
                   pert2case = i2dir + (i2pert-1)*3

                   blkflg(i1dir,i1pert,i2dir,i2pert,i3dir,i3pert) = 1


!                  Read the first-order densities from disk-files
                   rho2r1(:,:) = 0._dp ; rho2g1(:,:) = 0._dp

                   if (dtset%get1den /= 0 .or. dtset%ird1den /= 0) then
                     rdwr=1;rdwrpaw=0
                     call appdig(pert2case,dtfil%fildens1in,fiden1i)
                     call status(counter,dtfil%filstat,iexit,level,'call ioarr    ')
                     call ioarr(accessfil,rho2r1, dtset, etotal,fformr,fiden1i,hdr, mpi_enreg, &
&                     cplex*nfft,rhoij_dum,rdwr,rdwrpaw,wvl%descr)

!                    Compute up+down rho1(G) by fft
                     ABI_ALLOCATE(work,(cplex*nfft))
                     work(:)=rho2r1(:,1)
                     call status(counter,dtfil%filstat,iexit,level,'call fourdp   ')
                     call fourdp(cplex,rho2g1,work,-1,mpi_enreg,nfft,dtset%ngfft,dtset%paral_kgb,0)
                     ABI_DEALLOCATE(work)

                   end if




!                  Compute first-order local potentials
!                  (hartree, xc and pseudopotential)

                   n3xccc=0; if(psps%n1xccc/=0)n3xccc=nfft


                   xccc3d2(:)=0._dp ; vpsp1(:)=0._dp

                   if (i2pert <= natom) then

                     call status(counter,dtfil%filstat,iexit,level,'call vloca3   ')
                     call vloca3(atindx,cplex,gmet,gsqcut,i2dir,i2pert,mpi_enreg,psps%mqgrid_vl,natom,&
&                     nattyp,nfft,dtset%ngfft,psps%ntypat,n1,n2,n3,dtset%paral_kgb,ph1d,psps%qgrid_vl,&
&                     dtset%qptn,ucvol,psps%vlspl,vpsp1,xred)


                     if (psps%n1xccc/=0) then
                       call status(counter,dtfil%filstat,iexit,level,'call mkcor3   ')
                       call mkcor3(cplex,i2dir,i2pert,natom,psps%ntypat,n1,psps%n1xccc,&
&                       n2,n3,dtset%qptn,rprimd,dtset%typat,ucvol,&
&                       psps%xcccrc,psps%xccc1d,xccc3d2,xred)
                     end if ! psps%n1xccc/=0

                   end if  ! i2pert <= natom


                   call status(counter,dtfil%filstat,iexit,level,'call hartre   ')
                   call hartre(cplex,gmet,gsqcut,0,mpi_enreg,nfft,dtset%ngfft,dtset%paral_kgb,dtset%qptn,rho2g1,vhartr1)
                   option=1
                   call status(counter,dtfil%filstat,iexit,level,'call mkvxc3   ')
                   call mkvxc3(cplex,kxc,mpi_enreg,nfft,dtset%ngfft,nkxc,&
&                   dtset%nspden,n3xccc,option,dtset%paral_kgb,dtset%qptn,rho2r1,rprimd,vxc1,xccc3d2)





                   if(dtset%nsppol==1)then
                     if(cplex==1)then
                       do ir=1,nfft
                         vtrial1(ir,1)=vpsp1(ir)+vhartr1(ir)+vxc1(ir,1)
                       end do
                     else
                       do ir=1,nfft
                         vtrial1(2*ir-1,1)=vpsp1(2*ir-1)+vhartr1(2*ir-1)+vxc1(2*ir-1,1)
                         vtrial1(2*ir  ,1)=vpsp1(2*ir  )+vhartr1(2*ir  )+vxc1(2*ir  ,1)
                       end do
                     end if
                   else
                     if(cplex==1)then
                       do ir=1,nfft
                         vtrial1(ir,1)=vpsp1(ir)+vhartr1(ir)+vxc1(ir,1)
                         vtrial1(ir,2)=vpsp1(ir)+vhartr1(ir)+vxc1(ir,2)
                       end do
                     else

!                      fab: I think there was an error in the definition of  vtrial1(2*ir-1,2); I have corrected it...

                       do ir=1,nfft
                         vtrial1(2*ir-1,1)=vpsp1(2*ir-1)+vhartr1(2*ir-1)+vxc1(2*ir-1,1)
                         vtrial1(2*ir  ,1)=vpsp1(2*ir  )+vhartr1(2*ir  )+vxc1(2*ir  ,1)
                         vtrial1(2*ir-1,2)=vpsp1(2*ir-1)+vhartr1(2*ir-1)+vxc1(2*ir-1  ,2)
                         vtrial1(2*ir  ,2)=vpsp1(2*ir  )+vhartr1(2*ir  )+vxc1(2*ir  ,2)
                       end do
                     end if
                   end if

!                  DEBUG
!                  write(100,*)
!                  write(100,*)i1pert,i2pert,i3pert
!                  write(100,*)i1dir,i2dir,i3dir
!                  write(100,*)' ir    vpsp1     kxc     xccc3d1 '
!                  do ir=1,nfft,13
!                  write(100, '(i5,3es14.6)' ) ir,vpsp1(ir),kxc(ir,1),xccc3d1(ir)
!                  end do
!                  ENDDEBUG


!                  Compute the third-order xc energy
!                  take into account the contribution of the term
!                  $
!                  \frac{d}{d \lambda}
!                  \frac{\delta^2 E_{Hxc}}{\delta n(r) \delta n(r\prim)}
!                  $
!                  (seventh term of Eq. (110) of X. Gonze, PRA 52, 1096 (1995)).

!                  the following are essentially the 4th and the 3rd terms of PRB 71,125107, but the
!                  multiplication for rho1 will be done by dotprod_vn later

!                  in the non spin polarized case xc_tmp has only 1 component
                   if (nspden==1)then

                     ABI_ALLOCATE(xc_tmp,(cplex*nfft,1))

                     if (cplex==1) then

!                      This, and the next lines, have to be changed in case cplex=2

                       do ifft=1,nfft
                         xc_tmp(ifft,1)= k3xc(ifft,1)*(rho2r1(ifft,1)+3*xccc3d2(ifft))*rho3r1(ifft,1)
                       end do

                     else



                       do ifft=1,nfft   ! 2*ifft-1 denotes the real part, 2*ifft the imaginary part

                         xc_tmp(2*ifft-1,1)= k3xc(ifft,1)*( (rho2r1(2*ifft-1,1)+3*xccc3d2(2*ifft-1))*rho3r1(2*ifft-1,1) &
&                         -( rho2r1(2*ifft,1)+3*xccc3d2(2*ifft))*rho3r1(2*ifft,1))

                         xc_tmp(2*ifft,1)= k3xc(ifft,1)*( (rho2r1(2*ifft-1,1)+3*xccc3d2(2*ifft-1))*rho3r1(2*ifft,1) &
&                         +( rho2r1(2*ifft,1)+3*xccc3d2(2*ifft))*rho3r1(2*ifft-1,1))


                       end do

                     end if

                   end if


!                  fab: modifications for the spin polarized raman part:
!                  in the spin polarized case xc_tmp has 2 components
!                  note that now the non linear core correction is divided by 2



                   if (nspden==2) then

                     ABI_ALLOCATE(xc_tmp,(cplex*nfft,2))

                     if (cplex==1) then


                       do ifft=1,nfft

                         xc_tmp(ifft,1)= k3xc(ifft,1)*(rho2r1(ifft,2)+(3._dp/2._dp)*xccc3d2(ifft))*rho3r1(ifft,2)+ &
&                         k3xc(ifft,2)*(rho2r1(ifft,2)+(3._dp/2._dp)*xccc3d2(ifft))*(rho3r1(ifft,1)-rho3r1(ifft,2))+ &
&                         k3xc(ifft,2)*((rho2r1(ifft,1)-rho2r1(ifft,2))+(3._dp/2._dp)*xccc3d2(ifft))*rho3r1(ifft,2)+ &
&                         k3xc(ifft,3)*((rho2r1(ifft,1)-rho2r1(ifft,2))+(3._dp/2._dp)*xccc3d2(ifft))*(rho3r1(ifft,1)-rho3r1(ifft,2))

                         xc_tmp(ifft,2)= k3xc(ifft,2)*(rho2r1(ifft,2)+(3._dp/2._dp)*xccc3d2(ifft))*rho3r1(ifft,2)+ &
&                         k3xc(ifft,3)*(rho2r1(ifft,2)+(3._dp/2._dp)*xccc3d2(ifft))*(rho3r1(ifft,1)-rho3r1(ifft,2))+ &
&                         k3xc(ifft,3)*((rho2r1(ifft,1)-rho2r1(ifft,2))+(3._dp/2._dp)*xccc3d2(ifft))*rho3r1(ifft,2)+ &
&                         k3xc(ifft,4)*((rho2r1(ifft,1)-rho2r1(ifft,2))+(3._dp/2._dp)*xccc3d2(ifft))*(rho3r1(ifft,1)-rho3r1(ifft,2))


                       end do

                     else

                       do ifft=1,nfft

!                        These sections should be rewritten, to be easier to read ... (defining intermediate scalars)

                         xc_tmp(2*ifft-1,1)= k3xc(ifft,1)*&
&                         ( (rho2r1(2*ifft-1,2)+(3._dp/2._dp)*xccc3d2(2*ifft-1))*rho3r1(2*ifft-1,2)- &
&                         (rho2r1(2*ifft,2)+(3._dp/2._dp)*xccc3d2(2*ifft))*rho3r1(2*ifft,2))+   &
&                         k3xc(ifft,2)*&
&                         ( (rho2r1(2*ifft-1,2)+(3._dp/2._dp)*xccc3d2(2*ifft-1))*(rho3r1(2*ifft-1,1)-rho3r1(2*ifft-1,2))- &
&                         (rho2r1(2*ifft,2)+(3._dp/2._dp)*xccc3d2(2*ifft))*(rho3r1(2*ifft,1)-rho3r1(2*ifft,2)))+ &
&                         k3xc(ifft,2)*&
&                         ( ((rho2r1(2*ifft-1,1)-rho2r1(2*ifft-1,2))+(3._dp/2._dp)*xccc3d2(2*ifft-1))*rho3r1(2*ifft-1,2)- &
&                         ((rho2r1(2*ifft,1)-rho2r1(2*ifft,2))+(3._dp/2._dp)*xccc3d2(2*ifft))*rho3r1(2*ifft,2))+ &
&                         k3xc(ifft,3)*&
&                         ( ((rho2r1(2*ifft-1,1)-rho2r1(2*ifft-1,2))+(3._dp/2._dp)*xccc3d2(2*ifft-1))*&
&                         (rho3r1(2*ifft-1,1)-rho3r1(2*ifft-1,2))- &
&                         ((rho2r1(2*ifft,1)-rho2r1(2*ifft,2))+(3._dp/2._dp)*xccc3d2(2*ifft))*&
&                         (rho3r1(2*ifft,1)-rho3r1(2*ifft,2)))

                         xc_tmp(2*ifft,1)=k3xc(ifft,1)*&
&                         ( (rho2r1(2*ifft-1,2)+(3._dp/2._dp)*xccc3d2(2*ifft-1))*rho3r1(2*ifft,2)+ &
&                         (rho2r1(2*ifft,2)+(3._dp/2._dp)*xccc3d2(2*ifft))*rho3r1(2*ifft-1,2))+   &
&                         k3xc(ifft,2)*&
&                         ( (rho2r1(2*ifft-1,2)+(3._dp/2._dp)*xccc3d2(2*ifft-1))*(rho3r1(2*ifft,1)-rho3r1(2*ifft,2))+ &
&                         (rho2r1(2*ifft,2)+(3._dp/2._dp)*xccc3d2(2*ifft))*(rho3r1(2*ifft-1,1)-rho3r1(2*ifft-1,2)))+ &
&                         k3xc(ifft,2)*&
&                         ( ((rho2r1(2*ifft-1,1)-rho2r1(2*ifft-1,2))+(3._dp/2._dp)*xccc3d2(2*ifft-1))*rho3r1(2*ifft,2)+ &
&                         ((rho2r1(2*ifft,1)-rho2r1(2*ifft,2))+(3._dp/2._dp)*xccc3d2(2*ifft))*rho3r1(2*ifft-1,2))+ &
&                         k3xc(ifft,3)*&
&                         ( ((rho2r1(2*ifft-1,1)-rho2r1(2*ifft-1,2))+(3._dp/2._dp)*xccc3d2(2*ifft-1))*&
&                         (rho3r1(2*ifft,1)-rho3r1(2*ifft,2))+ &
&                         ((rho2r1(2*ifft,1)-rho2r1(2*ifft,2))+(3._dp/2._dp)*xccc3d2(2*ifft))*&
&                         (rho3r1(2*ifft-1,1)-rho3r1(2*ifft-1,2)))


!                        fab: now the spin down component

                         xc_tmp(2*ifft-1,2)= k3xc(ifft,2)*&
&                         ( (rho2r1(2*ifft-1,2)+(3._dp/2._dp)*xccc3d2(2*ifft-1))*rho3r1(2*ifft-1,2)- &
&                         (rho2r1(2*ifft,2)+(3._dp/2._dp)*xccc3d2(2*ifft))*rho3r1(2*ifft,2))+   &
&                         k3xc(ifft,3)*( (rho2r1(2*ifft-1,2)+(3._dp/2._dp)*xccc3d2(2*ifft-1))*&
&                         (rho3r1(2*ifft-1,1)-rho3r1(2*ifft-1,2))- &
&                         (rho2r1(2*ifft,2)+(3._dp/2._dp)*xccc3d2(2*ifft))*(rho3r1(2*ifft,1)-rho3r1(2*ifft,2)))+ &
&                         k3xc(ifft,3)*( ((rho2r1(2*ifft-1,1)-rho2r1(2*ifft-1,2))+(3._dp/2._dp)*xccc3d2(2*ifft-1))*&
&                         rho3r1(2*ifft-1,2)- &
&                         ((rho2r1(2*ifft,1)-rho2r1(2*ifft,2))+(3._dp/2._dp)*xccc3d2(2*ifft))*rho3r1(2*ifft,2))+ &
&                         k3xc(ifft,4)*( ((rho2r1(2*ifft-1,1)-rho2r1(2*ifft-1,2))+(3._dp/2._dp)*xccc3d2(2*ifft-1))*&
&                         (rho3r1(2*ifft-1,1)-rho3r1(2*ifft-1,2))- &
                         ((rho2r1(2*ifft,1)-rho2r1(2*ifft,2))+(3._dp/2._dp)*xccc3d2(2*ifft))*&
&                         (rho3r1(2*ifft,1)-rho3r1(2*ifft,2)))

                         xc_tmp(2*ifft,2)=k3xc(ifft,1)*( (rho2r1(2*ifft-1,2)+(3._dp/2._dp)*xccc3d2(2*ifft-1))*&
&                         rho3r1(2*ifft,2)+ &
&                         (rho2r1(2*ifft,2)+(3._dp/2._dp)*xccc3d2(2*ifft))*rho3r1(2*ifft-1,2))+   &
&                         k3xc(ifft,3)*( (rho2r1(2*ifft-1,2)+(3._dp/2._dp)*xccc3d2(2*ifft-1))*&
&                         (rho3r1(2*ifft,1)-rho3r1(2*ifft,2))+ &
&                         (rho2r1(2*ifft,2)+(3._dp/2._dp)*xccc3d2(2*ifft))*(rho3r1(2*ifft-1,1)-rho3r1(2*ifft-1,2)))+ &
&                         k3xc(ifft,3)*( ((rho2r1(2*ifft-1,1)-rho2r1(2*ifft-1,2))+(3._dp/2._dp)*xccc3d2(2*ifft-1))*&
&                         rho3r1(2*ifft,2)+ &
&                         ((rho2r1(2*ifft,1)-rho2r1(2*ifft,2))+(3._dp/2._dp)*xccc3d2(2*ifft))*rho3r1(2*ifft-1,2))+ &
&                         k3xc(ifft,4)*( ((rho2r1(2*ifft-1,1)-rho2r1(2*ifft-1,2))+(3._dp/2._dp)*xccc3d2(2*ifft-1))*&
&                         (rho3r1(2*ifft,1)-rho3r1(2*ifft,2))+ &
&                         ((rho2r1(2*ifft,1)-rho2r1(2*ifft,2))+(3._dp/2._dp)*xccc3d2(2*ifft))*&
&                         (rho3r1(2*ifft-1,1)-rho3r1(2*ifft-1,2)))

                       end do

!                      fab: this is the end if over cplex

                     end if

!                    fab: this is the enf if over nspden

                   end if



                   call dotprod_vn(1,rho1r1,exc3,valuei,mpi_enreg,nfft,nfftot,nspden,1,xc_tmp,ucvol)
                   ABI_DEALLOCATE(xc_tmp)

!                  Perform DFPT part of the 3dte calculation

                   call timab(512,1,tsec)
                   call status(counter,dtfil%filstat,iexit,level,'call resp3dte ')
                   call resp3dte(atindx,atindx1,cg,cg1,cg3,cplex,dtfil,dtset,d3lo,gmet,&
&                   gprimd,i1dir,i2dir,i3dir,i1pert,i2pert,i3pert,&
&                   kg,mband,mgfft,mkmem,mk1mem,&
&                   mpert,mpi_enreg,mpsang,mpw,natom,nfft,nkpt,nspden,nspinor,nsppol,&
&                   npwarr,occ,ph1d,psps,rmet,ucvol,vtrial1,xred,ylm)
                   call timab(512,2,tsec)

                   call status(counter,dtfil%filstat,iexit,level,'after resp3dte')

!                  Describe the perturbation and write out the result

                   if (mpi_enreg%me == 0) then

                     if (i2pert < natom + 1) then
                       write(message,'(a,i3,a,i3)') &
&                       ' j2 : displacement of atom ',i2pert,&
&                       ' along direction ', i2dir
                     end if

                     if (i2pert == dtset%natom + 2) then
                       write(message,'(a,i4)') &
&                       ' j2 : homogeneous electric field along direction ',&
&                       i2dir
                     end if
                     call wrtout(std_out,message,'COLL')
                     call wrtout(ab_out,message,'COLL')

                     write(ab_out,'(20x,a,13x,a)')'real part','imaginary part'
                     write(ab_out,'(5x,a2,1x,f22.10,3x,f22.10)')'xc',exc3*sixth,zero

                     if (i2pert == natom + 2) then
                       write(ab_out,'(5x,a3,f22.10,3x,f22.10)')'ddk',&
&                       d3_berry(1,i2dir),d3_berry(2,i2dir)
                     end if

                     write(ab_out,'(5x,a3,f22.10,3x,f22.10)')'dft',&
&                     d3lo(1,i1dir,i1pert,i2dir,i2pert,i3dir,i3pert),&
&                     d3lo(2,i1dir,i1pert,i2dir,i2pert,i3dir,i3pert)
                     write(ab_out,*)

                     write(std_out,'(18x,a,11x,a)')'real part','imaginary part'
                     write(std_out,'(5x,a2,1x,f20.10,3x,f20.10)')'xc',exc3*sixth,zero

                     write(std_out,'(5x,a3,f22.10,3x,f22.10)')'ddk',&
&                     d3_berry(1,i2dir),d3_berry(2,i2dir)

                     write(std_out,'(5x,a3,f22.10,3x,f22.10)')'dft',&
&                     d3lo(1,i1dir,i1pert,i2dir,i2pert,i3dir,i3pert),&
&                     d3lo(2,i1dir,i1pert,i2dir,i2pert,i3dir,i3pert)
                     write(std_out,*)

                   end if  ! mpi_enreg%me == 0


                   d3lo(1,i1dir,i1pert,i2dir,i2pert,i3dir,i3pert) = &
&                   d3lo(1,i1dir,i1pert,i2dir,i2pert,i3dir,i3pert) + exc3*sixth

                   d3lo(:,i1dir,i1pert,i2dir,i2pert,i3dir,i3pert) = &
&                   d3lo(:,i1dir,i1pert,i2dir,i2pert,i3dir,i3pert) + d3_berry(:,i2dir)

                 end if   !rfpert
               end do    !i2dir
             end do     ! i2pert

           end if   ! rfpert
         end do    ! i3dir
       end do     ! i3pert

     end if   ! rfpert
   end do    ! i1dir
 end do     ! i1pert

 call status(0,dtfil%filstat,iexit,level,'exit          ')

 ABI_DEALLOCATE(cg1)
 ABI_DEALLOCATE(cg3)
 ABI_DEALLOCATE(eigen1)
 ABI_DEALLOCATE(rho1r1)
 ABI_DEALLOCATE(rho2r1)
 ABI_DEALLOCATE(rho2g1)
 ABI_DEALLOCATE(rho3r1)
 ABI_DEALLOCATE(atindx1)
 ABI_DEALLOCATE(atindx)
 ABI_DEALLOCATE(nattyp)
 ABI_DEALLOCATE(ph1d)
 ABI_DEALLOCATE(ylm)
 ABI_DEALLOCATE(vtrial1)
 ABI_DEALLOCATE(vxc1)
 ABI_DEALLOCATE(vhartr1)
 ABI_DEALLOCATE(vpsp1)
 ABI_DEALLOCATE(xccc3d1)
 ABI_DEALLOCATE(xccc3d2)
 ABI_DEALLOCATE(xccc3d3)

 call timab(502,2,tsec)

!DEBUG
!write(std_out,*)' loop3dte : exit '
!ENDDEBUG

end subroutine loop3dte
!!***
