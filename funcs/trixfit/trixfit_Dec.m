function [y, name, pnames, pin]=trixfit(x,p,flag)
%
% TRIXFIT function [y, name, pnames, pin]=trixfit(x,p,Q1,Q2, flag)
% for fitting triple-axis data. 
% 
% S(Q,w) is convoluted with the 4D resolution function.
%
% Des McMorrow, October 2001

%----- Define global variables

global global_trixfit
global first_call
global global_b_mat global_fwhm global_R0 Qvec
global Hsc Ksc Lsc wsc

%----- Units: f energy units into k^2 (0.4826 for meV, 1.996854 for THz)
%      At the moment, only works for meV!

if nargin==2

    %----- Unpack parameters from global_trixfit
%        p
    
       f=0.4826;

    %-----  mon_flag: 1=monitor, 0=time

       mon_flag=global_trixfit.monitor_flag;                                             

    %----- Monte Carlo Steps for integration

       NMC=global_trixfit.monte_carlo_samples;

    %----- Cross-section

       xsec=global_trixfit.xsec_file;

    %----- Background definition

       bkgd_file=global_trixfit.bkgd_file;

    %----- Correction file

       corr_file=global_trixfit.corr_file;

    %-----  Method 

       method=global_trixfit.resolution_method;

    %----- Initialise y

       y=zeros(size(x));

    %----- Rescal params
    
       pres=global_trixfit.pres(:);
       
    %----- information needed to reconstruct the scan points for a non-equidistant scan:

       scan_len=length(x); % number of points in scan
       xvec=zeros(4,1);
       xvec(p(10))=1; % xvec is a vector in (Q,w) space with a non-zero entry in dir. of x (x= x-value of s1d-obj)
       Qs=reshape(p(1:4),4,1);
       Qe=reshape(p(5:8),4,1);
       dQ=Qe-Qs;
    
    %----- Calculate Q2c matrix

    if first_call==1
        % pres(19:21): lattice parameters a,b,c
        % pres(22:24): angles alpha, beta, gamma
        % pres(31:33): Q-point in [r.l.u.] coordinates
      [Q2c]=rc_re2rc([pres(19) pres(20) pres(21)], ... 
                     [pres(22) pres(23) pres(24)],...
                     [pres(31) pres(32) pres(33)]);
        % Q2c: matrix to transform a vector Q(H,K,L) into cart. coord. w. resp. to a
        %      basis with a || x and b in the x-y-plane
                 
    %----- Now work out transformations

    % A1,A2: the rec. lattice vectors in the scattering plane
      A1=[pres(25) pres(26) pres(27)]';
      A2=[pres(28) pres(29) pres(30)]';

      V1=Q2c*A1;
      V2=Q2c*A2;

    %----- Form unit vectors V1, V2, V3 in scattering plane

      V3=cross(V1,V2);
      V2=cross(V3,V1);
      V3=V3/sqrt(sum(V3.*V3));
      V2=V2/sqrt(sum(V2.*V2));
      V1=V1/sqrt(sum(V1.*V1));

      U=[V1';V2';V3']; % transforms from orthonormal (Qx,Qy,Qz) basis to an orthonormal basis 
                       % (V1,V2,V3) with a* �� V1, V2 perp. a*, c* in the
                       % (V1,V2)-plane, U has been verfied to be orthogonal

    %----- S transformation matrix from (h,k,l) to V1,V2,V3

      S=U*Q2c;     % This is used to bring the CN matrix into a defined frame.

    %----- Calculate resolution widths for scan etc

      for j=1:scan_len;
         % pres(31:34): H,K,L, w of scan, p(1:4): H,K,L, w as given in mfit
         t = (x(j)-Qs'*xvec)/(dQ'*xvec);
         pres(31)=Qs(1)+t*dQ(1);
         pres(32)=Qs(2)+t*dQ(2);
         pres(33)=Qs(3)+t*dQ(3);
         pres(34)=Qs(4)+t*dQ(4);
   
    %----- Calculate focusing curvatures        
        
         if strcmp(method,'rc_popma')
            rho=rc_focus(pres);% calculates the curvature radii in [1/m]
 %            pres(66)=rho(1)*(pres(66)<0);
 %            pres(67)=rho(2)*(pres(67)<0);
 %            pres(68)=rho(3)*(pres(68)<0);
 %            pres(69)=rho(4)*(pres(69)<0);
% can't see the purpose of the pres(66)< 0, since it makes the curvature
% radii to zero, the first time, after the have a positive value or zero,
% if it would be called with these values again. Since these are expected
% to be executed once when calling trixfit, this seems strange.
%              pres(66)=0;% mono. horz. foc. in 1/cm
% %             pres(67)=1E-2*rho(2);% mon. vert. foc. in 1/cm
% %             pres(68)=1E-2*rho(3);% ana. horz. foc. in 1/cm
%              pres(67)=rho(2);% mon. vert. foc. in 1/cm
%              pres(68)=rho(3);% ana. horz. foc. in 1/cm
%              pres(69)=rho(4);% ana. vert. foc. in 1/cm
             
             pres(66)=rho(1)*(pres(66)<0);
             pres(67)=rho(2)*(pres(67)<0);
             pres(68)=rho(3)*(pres(68)<0);
             pres(69)=rho(4)*(pres(69)<0);
        
         end
        
    %----- Q vector in cartesian coordinates

         Qcart=Q2c*pres(31:33);
         Qmag=sqrt(sum(Qcart.*Qcart));
 
    %----- Resolution matrix in Q frame. NP is resolution matrix in Qx, Qy & Qz
         [R0,NP,vi,vf,Error]=feval(method,f,Qmag,pres,mon_flag);

    %----- Use correction of resolution volume

 %     R0_corrected=R0/(sqrt(det(NP))/((2*pi)^2)); %this is contained in
  %       the orig. version, but seems wrong when comparing it to reslib
%      R0_corrected=R0*(sqrt(det(NP))/((2*pi)^2));
%          [R0 R0_corrected (sqrt(det(NP))/((2*pi)^2))]
% when applying Bertrand`s R0, all factors are included in the rc_popma:
        R0_corrected=R0/sqrt(det(NP))/(2*pi)^2;
    %----- Work out angle of Q wrt to V1, V2
      
         TT=S*[pres(31) pres(32) pres(33)]';% Q in V1,V2,V3 coord. sys.
         cos_theta=TT(1)/sqrt(sum(TT.*TT));
         sin_theta=TT(2)/sqrt(sum(TT.*TT));

    %----- Rotation matrix from Q to V1,V2,V3

         R=[cos_theta sin_theta 0; -sin_theta cos_theta 0; 0 0 1];
%         ph=-11;
%          R=[cos_theta sin_theta 0; -sin_theta cos_theta 0; 0 0 1]*[cos(ph/180*pi) sin(ph/180*pi) 0; -sin(ph/180*pi) cos(ph/180*pi) 0;0 0 1];

         T=zeros(4,4);
         T(4,4)=1;
         T(1:3,1:3)=R*S;

    %----- Resolution ellipsoid in terms of H,K,L,EN ([Rlu] & [meV]) 

         M=T'*NP*T; % This is the matrix of the quadratic form NP, when the Q-vectors are given
                    % in (h,k,l) coordinates    
         
         [V,E]=eig(M);% V contains the normalized eigenvectors of M,
         fwhm=zeros(1,4);
         fwhm(1)=1/sqrt(E(1,1));
         fwhm(2)=1/sqrt(E(2,2));
         fwhm(3)=1/sqrt(E(3,3));
         fwhm(4)=1/sqrt(E(4,4));
%         b_mat=reshape(inv((V'))',1,16);
         b_mat=reshape(inv((V'))',1,16);
         
         global_b_mat(j,:)=b_mat;
         global_fwhm(j,:)=fwhm;
         global_R0(j)=R0_corrected;
                 
      end
    first_call=0;

    end

    %----- Calculate function
    load_the_matrices=1;
    for j=1:scan_len;
        
    %----- Evaluate the cross-section and do the Monte Carlo integration
        t = (x(j)-Qs'*xvec)/(dQ'*xvec);
        Qvec(j,:) = [Qs(1)+t*dQ(1) Qs(2)+t*dQ(2) Qs(3)+t*dQ(3) Qs(4)+t*dQ(4)];
        s = feval(xsec,NMC,Qvec(j,:),p,global_fwhm(j,1:4),global_b_mat(j,1:16),load_the_matrices);
    %----- Calculate normalised intensity
        
        y(j)=global_R0(j)*s;

    end	

    %----- Apply correction factor to calculated intensity, eg for lambda/2 in
    %      incident beam

    y=feval(corr_file,x,y);

    %----- Add background

    y=y+feval(bkgd_file,x,p);
    %         y=smooth(y,round(length(y)/6));
    try
        y=smooth(real(y),length(x)/20,'sgolay');
    catch
    end
else
%----- Parameter names

   y=[];
   pin=[];
   pnam_file=global_trixfit.pnam_file;
         
   name='trixfit';
   pnames=feval(pnam_file,p);      

end
