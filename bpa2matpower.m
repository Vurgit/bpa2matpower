% ��ȡBPA��ʽ�����ļ�������MATPOWER������������ĸ���б�
% Reading BPA file,generating grid and bus info for MATPOWER
function [mpc, buslist] = bpa2matpower(bpafile)
% 1. ����BPA�ļ�����������
% 1.Reading BPA file
disp(['����ԭʼBPA�����ļ�', bpafile, '������...  ','  Reading original BPA powerflow file ',bpafile,'...']);
% 1.1. ��BPA�����ļ�
% 1.1 Opening BPApowerflow file
fid = fopen(bpafile, 'r');
% 1.2. ���������ݶ��뵽�ַ���������
% 1.2  Reading all the content to a cell
bpa_info = cell(5000, 1);
ii = 1;
while (~feof(fid))
    newline = fgetl(fid);
    bpa_info(ii) = {newline};
    ii = ii + 1;
end
% 1.3. ��δ���õ���Ԥ��������Ԫ����ռ��Դ�ͷŵ�
% 1.3. Releasing resources for unused cells
for jj = ii : 5000
    bpa_info(ii) = [];
end
% 1.3. �ر�BPA�����ļ�
% 1.3. Closing BPA file
fclose(fid);
% 2. ����MatPower������������ĸ�������б�
% 2. Generating BPA grid data and bus name list
% 2.1. �õ�ĸ�߸�����֧·��������׼����
% 2.1  Getting basic grid data��Number of buses and branches and baseMVA
busNumber = 0;
genNumber = 0;
branchNumber = 0;
baseMVA=100;
disp('��õ�������������ĸ�߸�����֧·��������׼������...  Getting basic grid data��Number of buses and branches and baseMVA)...');
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    % 2.1.1. ��û�׼����
    if (length(thisline) >= 13 && strcmp(thisline(2 : 9), 'MVA_BASE'))
        baseMVA = str2double(thisline(11 : 13));
    end
    % 2.1.2. ͳ��ĸ�߸���
    if (length(thisline) > 2 && strcmp(thisline(1), 'B'))
        busNumber = busNumber + 1;
        if (strcmp(thisline(1 : 2), 'BS') || strcmp(thisline(1 : 2), 'BE') || strcmp(thisline(1 : 2), 'BQ'))
            genNumber = genNumber + 1;
        end
    end
    % 2.1.3. ͳ��֧·����
    if (length(thisline) > 2 && (strcmp(thisline(1), 'L') || strcmp(thisline(1), 'T')))
        branchNumber = branchNumber + 1;
    end
end
% 2.2. �õ�ĸ�߾��󣬷��������֧·����ĸ���б�
% 2.2.1. �õ�ĸ�߾����ĸ�������б�
% 2.2 Getting bus matrix,generator matrix,branch matrix,bus list
busMatrix = zeros(busNumber, 13);
buslist = cell(busNumber, 1);
busIndex = 0;
disp('���ĸ�߾����ĸ�������б�...  Getting bus matrix and bus name list...');
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if (length(thisline) < 72)  % �ڳ��Ȳ���72���ַ������油��ո� 
% Add space for char(string?) shorter than 72(One Chinese character is 1
% space)
        thisline = [thisline, blanks(72 - length(thisline))];
    end
    if (strcmp(thisline(1), 'B'))
        busIndex = busIndex + 1;
        busMatrix(busIndex, 1) = busIndex;  % ĸ�߱�� Bus no
        switch thisline(2)  % ĸ������ Bus type
            case {' ', 'T', 'C', 'V'}   % PQ�ڵ�
                busMatrix(busIndex, 2) = 1;
            case {'E', 'Q', 'G'}    % PV�ڵ�
                busMatrix(busIndex, 2) = 2;
            case 'S'    % ƽ��ڵ� Slack bus
                busMatrix(busIndex, 2) = 3;
        end
        if (~strcmp(thisline(21 : 25), blanks(5)))
            busMatrix(busIndex, 3) = str2double(thisline(21 : 25));   % �й����� P load
        else
            busMatrix(busIndex, 3) = 0.0;   % �й�����
        end
        if (~strcmp(thisline(26 : 30), blanks(5)))
            busMatrix(busIndex, 4) = str2double(thisline(26 : 30));   % �޹����� Q load
        else
            busMatrix(busIndex, 4) = 0.0;   % �޹�����
        end
        if (~strcmp(thisline(31 : 34), blanks(4)))
            busMatrix(busIndex, 5) = str2double(thisline(31 : 34));   % �Եص絼���ö��ѹ���й�����ʾ��
                                                                      %Ground-conductance(P under rated voltage)                                                                                                                                            
        else
            busMatrix(busIndex, 5) = 0.0;   % �Եص絼���ö��ѹ���й�����ʾ��
        end
        if (~strcmp(thisline(35 : 38), blanks(4)))
            busMatrix(busIndex, 6) = str2double(thisline(35 : 38));   % �Եص��ɣ��ö��ѹ���޹�����ʾ������Ϊ����
                                                                      %Ground susceptance(Q under rated voltage,capacitive-is-positive                                                                      
        else
            busMatrix(busIndex, 6) = 0.0;   % �Եص��ɣ��ö��ѹ���޹�����ʾ������Ϊ����
        end
        busMatrix(busIndex, 7) = 1;   % ĸ������area������***������ʱ�ٶ�ȫ��ֻ��һ��area������ɸĽ���
                                      %bus area(let it be all the same)
        if (~strcmp(thisline(58 : 61), blanks(4)))
            thisVoltage = str2double(thisline(58 : 61));
            while (thisVoltage > 2)
                thisVoltage = thisVoltage / 10;
            end
            busMatrix(busIndex, 8) = thisVoltage;   % ĸ�ߵ�ѹֵ
                                                    %bus voltage amplitude
        else
            busMatrix(busIndex, 8) = 1.0;   % ĸ�ߵ�ѹֵ
        end
        busMatrix(busIndex, 9) = 0.0; % ĸ�����ֵ
                                      % bus angle 
        busMatrix(busIndex, 10) = str2double(thisline(15 : 18));  % ĸ�ߵ�ѹ�ȼ�
                                                                  % bus baseKV
        busMatrix(busIndex, 11) = 1;  % ĸ������zone������***������ʱ�ٶ�ȫ��ֻ��һ��zone������ɸĽ���
        if (~strcmp(thisline(58 : 61), blanks(4)))
            thisVoltageMax = str2double(thisline(58 : 61));
            while (thisVoltageMax > 2)
                thisVoltageMax = thisVoltageMax / 10;
            end
            busMatrix(busIndex, 12) = thisVoltageMax;  % ��ѹ���ֵMax Voltage
        else
            busMatrix(busIndex, 12) = 1.5;  % ��ѹ���ֵ
        end
        if (~strcmp(thisline(62 : 65), blanks(4)))
            thisVoltageMin = str2double(thisline(62 : 65));
            while (thisVoltageMin > 2)
                thisVoltageMin = thisVoltageMin / 10;
            end
            busMatrix(busIndex, 13) = thisVoltageMin;  % ��ѹ��Сֵ Min voltage
        else
            busMatrix(busIndex, 13) = 0.5;  % ��ѹ��Сֵ
        end
        buslist(busIndex) = {thisline(7 : 14)}; % ĸ�������б�
    end
end
% 2.2.2. �õ����������11~21���ȶ���0��Getting generator matrix(0 for column 11-21
% first)
disp('��÷��������...  Getting generator matrix...');
genMatrix = zeros(genNumber, 21);
genIndex = 0;
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if (length(thisline) < 65)  % �ڳ��Ȳ���65���ַ������油��ո�
                                % add space for shorter than 65
        thisline = [thisline, blanks(65 - length(thisline))];
    end
    if (strcmp(thisline(1 : 2), 'BE') || strcmp(thisline(1 : 2), 'BQ') || strcmp(thisline(1 : 2), 'BG') || strcmp(thisline(1 : 2), 'BS'))   % PV�ڵ��ƽ��ڵ�
        genIndex = genIndex + 1;
        busname = thisline(7 : 14);
        for jj = 1 : busNumber    % ���������ĸ������
            if (strcmp(buslist(jj), busname))
                genMatrix(genIndex, 1) = jj;
                break;
            end
        end
        if (~strcmp(thisline(43 : 47), blanks(5)))
            genMatrix(genIndex, 2) = str2double(thisline(43 : 47));   % �����ʵ���й�����Actual Pout
        else
            genMatrix(genIndex, 2) = 0.0;   % �����ʵ���й�����
        end
        genMatrix(genIndex, 3) = 0.0;   % �����ʵ���޹���������PV�ڵ��ڳ�����������л��޸ģ�������ʱ����д����ֵ
                                        %Actual Qout,meaningless for PV buses
        if (~strcmp(thisline(48 : 52), blanks(5)))
            genMatrix(genIndex, 4) = str2double(thisline(48 : 52));   % ���������޹�����
        else
            genMatrix(genIndex, 4) = 9999.99;   % ���������޹�����
        end
        if (~strcmp(thisline(53 : 57), blanks(5)))
            genMatrix(genIndex, 5) = str2double(thisline(53 : 57));   % �������С�޹�����
        else
            genMatrix(genIndex, 5) = 0.0;   % �������С�޹�����
        end
        if (~strcmp(thisline(58 : 61), blanks(4)))
            thisVoltage = str2double(thisline(58 : 61));
            while (thisVoltage > 2)
                thisVoltage = thisVoltage / 10;
            end
            genMatrix(genIndex, 6) = thisVoltage;   % �������������ĸ�ߵ�ѹ��ֵ
        else
            genMatrix(genIndex, 6) = 1.0;   % �������������ĸ�ߵ�ѹ��ֵ
        end
        genMatrix(genIndex, 7) = baseMVA;   % ������������������ʱȡȫ����׼����
        genMatrix(genIndex, 8) = 1; % ���������״̬��Ĭ��ΪͶ������
        if (~strcmp(thisline(39 : 42), blanks(4)))
            genMatrix(genIndex, 9) = str2double(thisline(39 : 42));   % ���������й�����
        else
            genMatrix(genIndex, 9) = 9999.99;   % ���������й�����
        end
        genMatrix(genIndex, 10) = 0.0;  % �������С�й�����
    end
end
% 2.2.3. �õ�֧·����
disp('���֧·����...   Getting branch matrix...');
branchMatrix = zeros(branchNumber, 13);
branchIndex = 0;
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if (length(thisline) < 72)  % �ڳ��Ȳ���72���ַ������油��ո�
        thisline = [thisline, blanks(72 - length(thisline))];
    end
    if (strcmp(thisline(1), 'L') || strcmp(thisline(1), 'T'))   % ��·���ѹ��line or transformer
        branchIndex = branchIndex + 1;
        busname1 = thisline(7 : 14);
        for jj = 1 : busNumber    % ֧·��ʼ��ĸ������from and to buses
            if (strcmp(buslist(jj), busname1))
                branchMatrix(branchIndex, 2) = jj;
                break;
            end
        end
        busname2 = thisline(20 : 27);
        for jj = 1 : busNumber    % ֧·��ֹ��ĸ������
            if (strcmp(buslist(jj), busname2))
                branchMatrix(branchIndex, 1) = jj;
                break;
            end
        end
        if (~strcmp(thisline(39 : 44), blanks(6)))
            value = thisline(39 : 44);
            branchMatrix(branchIndex, 3) = str2double(value);   % ֧·����
            dotindex = findstr(value, '.');
            if (size(dotindex, 1) == 0 && size(dotindex, 2) == 0)
                branchMatrix(branchIndex, 3) = branchMatrix(branchIndex, 3) / 100000;
            end
        else
            branchMatrix(branchIndex, 3) = 0.0;   % ֧·����
        end
        if (~strcmp(thisline(45 : 50), blanks(6)))
            value = thisline(45 : 50);
            branchMatrix(branchIndex, 4) = str2double(value);   % ֧·�翹
            dotindex = findstr(value, '.');
            if (size(dotindex, 1) == 0 && size(dotindex, 2) == 0)
                branchMatrix(branchIndex, 4) = branchMatrix(branchIndex, 4) / 100000;
            end
        else
            branchMatrix(branchIndex, 4) = 0.0;   % ֧·�翹
        end
        if (~strcmp(thisline(57 : 62), blanks(6)))
            branchMatrix(branchIndex, 5) = str2double(thisline(57 : 62)) * 2;   % ֧·�Եص��ɣ�BPA��ΪB/2����Ӧ��ԭ���ݳ���2
        else
            branchMatrix(branchIndex, 5) = 0.0;   % ֧·�翹
        end
        % ������·���ѹ�����ڡ����ںͽ�������µĶ������BPAû����Ӧ���ݣ���ʱ����ȫ�������
        branchMatrix(branchIndex, 6) = baseMVA;
        branchMatrix(branchIndex, 7) = baseMVA;
        branchMatrix(branchIndex, 8) = baseMVA;
        % ֧·�Ǳ�׼���
        if (strcmp(thisline(1), 'L'))
            branchMatrix(branchIndex, 9) = 1.0; % �����·�����ڷǱ�׼��ȵ�����
        elseif (strcmp(thisline(1), 'T'))
            vbase1 = str2double(thisline(15 : 18));
            vbase2 = str2double(thisline(28 : 31));
            vset1 = str2double(thisline(63 : 67));
            vset2 = str2double(thisline(68 : 72));
            kset = vset1 / vset2;
            kbase = vbase1 / vbase2;
            kpu = kset / kbase;
            % ������BPA�����ݵ�FORTRAN��ʽ��ɵĶ�ȡ���ݴ���
            % Fixxing FORTRAN-caused dataform problem
            while kpu > 10
                kpu = kpu / 10;
            end
            while kpu < 0.1
                kpu = kpu * 10;
            end
            branchMatrix(branchIndex, 9) = 1 / kpu; % ��ѹ���Ǳ�׼��ȵ�ƫ����
        end
        branchMatrix(branchIndex, 10) = 0.0;    % û������
        branchMatrix(branchIndex, 11) = 1;  % ֧·����״̬��Ĭ��Ϊ����
        branchMatrix(branchIndex, 12) = -360.0; % ����ĸ����С��ǲ�
        branchMatrix(branchIndex, 13) = 360.0; % ����ĸ�������ǲ�
        
%         kpu = branchMatrix(branchIndex, 9);
%         branchMatrix(branchIndex, 3) = branchMatrix(branchIndex, 3) / kpu / kpu;
%         branchMatrix(branchIndex, 4) = branchMatrix(branchIndex, 4) / kpu / kpu;
%         branchMatrix(branchIndex, 5) = branchMatrix(branchIndex, 5) * kpu * kpu;
    end
end
% 2.2.4. �õ����������ɱ�����
disp('��÷��������ɱ�����...   Getting gencost matrix...');
gencostMatrix = zeros(genNumber, 7);
% 2.3. ���������صĵ�������ĸ���б�
mpc = struct('version', '2', 'baseMVA', baseMVA, 'bus', busMatrix, 'gen', genMatrix, 'branch', branchMatrix, 'areas', [], 'gencost', gencostMatrix);
disp(['�ɹ���bpa��ʽ�����ļ�',bpafile, 'ת����matPower���ݶ���',  'BPA file ', bpafile, ' converted to matPower struct successfully��']);
