a=bpa2matpower('118bpa.dat');
runpf(a);
b=bpa2matpower('ieee90.dat');
runpf(b);
% c=bpa2matpower('F:\���޸ĵ��������ĵ�\���е�ֵǰV5.0-��ֱ��.dat');
% runpf(c);
% a=cell(2,1);
% a{3,1}='��׳� 2201';
% a{1,1}='�󱿵� 220';
% a{2,1}='���¿ 220';
% c=cell2mat(a(2,1));
% b='��׳� 220.';
% find(strcmp(a,b)|strncmp(a,b,7));
% a{2,1}(1,2);
% 
% a{2,1}(find(a{2,1}=='2'))='3';
% 
