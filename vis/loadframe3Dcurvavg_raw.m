function [ne,v1,Ti,Te,J1,v2,v3,J2,J3,Phitop] = loadframe3Dcurvavg_raw(direc, filename)

narginchk(2,2)
%% SIMULATION SIZE
lxs = simsize(direc);
%% SIMULATION GRID FILE
% (NOTE THAT THIS IS NOT THE ENTIRE THING - THAT NEEDS TO BE DONE WITH READGRID.M.  WE NEED THIS HERE TO DO MESHGRIDS
%[x1, x2, x3] = simaxes(direc);
%% SIMULATION RESULTS
fsimres = [direc,filesep,filename];
assert(is_file(fsimres), [fsimres,' is not a file.'])

fid=fopen(fsimres,'r');
simdt(fid);
%% Number densities
ne = read3D(fid, lxs);
%% Parallel Velocities
v1 = read3D(fid, lxs);
%% Temperatures
Ti = read3D(fid, lxs);
Te = read3D(fid, lxs);
%% Current densities
J1 = read3D(fid, lxs);
J2 = read3D(fid, lxs);
J3 = read3D(fid, lxs);
%% Perpendicular drifts
v2 = read3D(fid, lxs);
v3 = read3D(fid, lxs);
%% Topside potential
Phitop = read2D(fid, lxs);

fclose(fid);

%% REORGANIZE ACCORDING TO MATLABS CONCEPT OF A 2D or 3D DATA SET
if lxs(2) == 1    %a 2D simulations was done in x1 and x3
 % disp('Detected a 2D simulation (x1,x3) and organizing data accordingly.')
 % Jpar=squeeze(J1);
 % Jperp2=squeeze(J3);
%  ne=squeeze(ns(:,:,:,lsp));
%  p=ns(:,:,:,1)./ns(:,:,:,lsp);
%  p=squeeze(p);
%  vi=squeeze(v1);
%  vi2=squeeze(v2);
%  vi3=permute(v3,[3,2,1]);
%  Ti=sum(ns(:,:,:,1:6).*Ts(:,:,:,1:6),4)./ns(:,:,:,lsp);
  Ti=squeeze(Ti);
%  Te=squeeze(Ts(:,:,:,lsp));
  Te=squeeze(Te);

 % [X3,X1]=meshgrid(x3,x1);
elseif (lxs(3)==1)     %a 2D simuluation was done in x1,x2 with internal permutign of arrays by fortran code
 % disp('Detected a 2D simulation (x1,x2) and organizing data accordingly.')
  %Jpar=squeeze(J1);
  %Jperp2=squeeze(J3);
  %vi=squeeze(v1);
  %vi2=squeeze(v2);
  Ti=squeeze(Ti);
  Te=squeeze(Te);

  %[X2,X1]=meshgrid(x2,x1);
else    %full 3D run
 % disp('Detected a 3D simulation and organizing data accordingly.')
  %Jpar=permute(J1(:,:,:),[3,2,1]);
  %Jperp2=permute(J2(:,:,:),[3,2,1]);
  %Jperp3=permute(J3(:,:,:),[3,2,1]);
%  ne=permute(ns(:,:,:,lsp),[3,2,1]);
%  p=ns(:,:,:,1)./ns(:,:,:,lsp);
%  p=permute(p,[3,2,1]);
  %vi=permute(v1,[3,2,1]);
  %vi2=permute(v2,[3,2,1]);
  %vi3=permute(v3,[3,2,1]);
%  Ti=sum(ns(:,:,:,1:6).*Ts(:,:,:,1:6),4)./ns(:,:,:,lsp);
%  Ti=permute(Ti,[3,2,1]);
%  Te=permute(Ts(:,:,:,lsp),[3,2,1]);
%  Te=permute(Te,[3,2,1]);

  %[X2,X3,X1]=meshgrid(x2,x3,x1);
end % if

end % function
