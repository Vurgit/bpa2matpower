a=bpa2matpower('118bpa.dat');
runpf(a);
b=bpa2matpower('ieee90.dat');
runpf(b);
% c=bpa2matpower('F:\待修改的论文与文档\藏中等值前V5.0-无直流.dat');
% runpf(c);
% a=cell(2,1);
% a{3,1}='大白痴 2201';
% a{1,1}='大笨蛋 220';
% a{2,1}='大蠢驴 220';
% c=cell2mat(a(2,1));
% b='大白痴 220.';
% find(strcmp(a,b)|strncmp(a,b,7));
% a{2,1}(1,2);
% 
% a{2,1}(find(a{2,1}=='2'))='3';
% 
