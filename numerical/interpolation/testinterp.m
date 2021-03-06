function testinterp(filename, realbits)

narginchk(1,2)
cwd = fileparts(mfilename('fullpath'));
addpath([cwd,filesep,'..',filesep,'..',filesep,'script_utils'])

if nargin == 1
  realbits = 64;
end

validateattr(realbits, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename,'real bits',2)
exist_or_skip(filename, 'file')

switch realbits
  case 64, freal = 'float64';
  case 32, freal = 'float32';
  otherwise, error(['unknown precision', num2str(realbits)])
end

fid=fopen(filename,'r');

lx1=fread(fid,1,'integer*4');
lx2=fread(fid,1,'integer*4');
assert(lx1==500)
assert(lx2==1000)

x1=fread(fid,lx1, freal);
x2=fread(fid,lx2, freal);
f=fread(fid,lx1*lx2, freal);
f=reshape(f,[lx1, lx2]);

fclose(fid);

if ~isinteractive
  return
end
%% PLOT
figure

if (lx2==1)
  plot(x1,f);
  xlabel('x_1')
  ylabel('f')
  title('1-D interp')
else
  imagesc(x2,x1,f);
  axis xy;
  xlabel('x_2')
  ylabel('x_1')
  c=colorbar;
  ylabel(c,'f')
  title('2-D interp')
end
%print -dpng -r300 ~/testinterp.png;

end % function
