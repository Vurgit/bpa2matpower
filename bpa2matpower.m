% 读取BPA格式数据文件，生成MATPOWER所需电网对象和母线列表
% Reading BPA file,generating grid and bus info for MATPOWER
function [mpc, buslist] = bpa2matpower(bpafile)
% 1. 读入BPA文件的所有内容
% 1.Reading BPA file
disp(['读入原始BPA潮流文件', bpafile, '的内容...  ','  Reading original BPA powerflow file ',bpafile,'...']);
% 1.1. 打开BPA潮流文件
% 1.1 Opening BPApowerflow file
fid = fopen(bpafile, 'r');
% 1.2. 将所有内容读入到字符串集合中
% 1.2  Reading all the content to a cell
bpa_info = cell(5000, 1);
ii = 1;
while (~feof(fid))
    newline = fgetl(fid);
    bpa_info(ii) = {newline};
    ii = ii + 1;
end
% 1.3. 将未利用到的预分配数组元素所占资源释放掉
% 1.3. Releasing resources for unused cells
for jj = ii : 5000
    bpa_info(ii) = [];
end
% 1.3. 关闭BPA潮流文件
% 1.3. Closing BPA file
fclose(fid);
% 2. 生成MatPower电力网络对象和母线名称列表
% 2. Generating BPA grid data and bus name list
% 2.1. 得到母线个数，支路个数，基准容量
% 2.1  Getting basic grid data（Number of buses and branches and baseMVA
busNumber = 0;
genNumber = 0;
branchNumber = 0;
baseMVA=100;
disp('获得电网基本参数（母线个数，支路个数，基准容量）...  Getting basic grid data（Number of buses and branches and baseMVA)...');
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    % 2.1.1. 获得基准容量
    if (length(thisline) >= 13 && strcmp(thisline(2 : 9), 'MVA_BASE'))
        baseMVA = str2double(thisline(11 : 13));
    end
    % 2.1.2. 统计母线个数
    if (length(thisline) > 2 && strcmp(thisline(1), 'B'))
        busNumber = busNumber + 1;
        if (strcmp(thisline(1 : 2), 'BS') || strcmp(thisline(1 : 2), 'BE') || strcmp(thisline(1 : 2), 'BQ'))
            genNumber = genNumber + 1;
        end
    end
    % 2.1.3. 统计支路个数
    if (length(thisline) > 2 && (strcmp(thisline(1), 'L') || strcmp(thisline(1), 'T')))
        branchNumber = branchNumber + 1;
    end
end
% 2.2. 得到母线矩阵，发电机矩阵，支路矩阵，母线列表
% 2.2.1. 得到母线矩阵和母线名称列表
% 2.2 Getting bus matrix,generator matrix,branch matrix,bus list
busMatrix = zeros(busNumber, 13);
buslist = cell(busNumber, 1);
busIndex = 0;
disp('获得母线矩阵和母线名称列表...  Getting bus matrix and bus name list...');
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if (length(thisline) < 72)  % 在长度不足72的字符串后面补足空格 
% Add space for char(string?) shorter than 72(One Chinese character is 1
% space)
        thisline = [thisline, blanks(72 - length(thisline))];
    end
    if (strcmp(thisline(1), 'B'))
        busIndex = busIndex + 1;
        busMatrix(busIndex, 1) = busIndex;  % 母线编号 Bus no
        switch thisline(2)  % 母线类型 Bus type
            case {' ', 'T', 'C', 'V'}   % PQ节点
                busMatrix(busIndex, 2) = 1;
            case {'E', 'Q', 'G'}    % PV节点
                busMatrix(busIndex, 2) = 2;
            case 'S'    % 平衡节点 Slack bus
                busMatrix(busIndex, 2) = 3;
        end
        if (~strcmp(thisline(21 : 25), blanks(5)))
            busMatrix(busIndex, 3) = str2double(thisline(21 : 25));   % 有功负荷 P load
        else
            busMatrix(busIndex, 3) = 0.0;   % 有功负荷
        end
        if (~strcmp(thisline(26 : 30), blanks(5)))
            busMatrix(busIndex, 4) = str2double(thisline(26 : 30));   % 无功负荷 Q load
        else
            busMatrix(busIndex, 4) = 0.0;   % 无功负荷
        end
        if (~strcmp(thisline(31 : 34), blanks(4)))
            busMatrix(busIndex, 5) = str2double(thisline(31 : 34));   % 对地电导（用额定电压下有功来表示）
                                                                      %Ground-conductance(P under rated voltage)                                                                                                                                            
        else
            busMatrix(busIndex, 5) = 0.0;   % 对地电导（用额定电压下有功来表示）
        end
        if (~strcmp(thisline(35 : 38), blanks(4)))
            busMatrix(busIndex, 6) = str2double(thisline(35 : 38));   % 对地电纳（用额定电压下无功来表示，容性为正）
                                                                      %Ground susceptance(Q under rated voltage,capacitive-is-positive                                                                      
        else
            busMatrix(busIndex, 6) = 0.0;   % 对地电纳（用额定电压下无功来表示，容性为正）
        end
        busMatrix(busIndex, 7) = 1;   % 母线所在area索引（***这里暂时假定全网只有一个area，后面可改进）
                                      %bus area(let it be all the same)
        if (~strcmp(thisline(58 : 61), blanks(4)))
            thisVoltage = str2double(thisline(58 : 61));
            while (thisVoltage > 2)
                thisVoltage = thisVoltage / 10;
            end
            busMatrix(busIndex, 8) = thisVoltage;   % 母线电压值
                                                    %bus voltage amplitude
        else
            busMatrix(busIndex, 8) = 1.0;   % 母线电压值
        end
        busMatrix(busIndex, 9) = 0.0; % 母线相角值
                                      % bus angle 
        busMatrix(busIndex, 10) = str2double(thisline(15 : 18));  % 母线电压等级
                                                                  % bus baseKV
        busMatrix(busIndex, 11) = 1;  % 母线所在zone索引（***这里暂时假定全网只有一个zone，后面可改进）
        if (~strcmp(thisline(58 : 61), blanks(4)))
            thisVoltageMax = str2double(thisline(58 : 61));
            while (thisVoltageMax > 2)
                thisVoltageMax = thisVoltageMax / 10;
            end
            busMatrix(busIndex, 12) = thisVoltageMax;  % 电压最大值Max Voltage
        else
            busMatrix(busIndex, 12) = 1.5;  % 电压最大值
        end
        if (~strcmp(thisline(62 : 65), blanks(4)))
            thisVoltageMin = str2double(thisline(62 : 65));
            while (thisVoltageMin > 2)
                thisVoltageMin = thisVoltageMin / 10;
            end
            busMatrix(busIndex, 13) = thisVoltageMin;  % 电压最小值 Min voltage
        else
            busMatrix(busIndex, 13) = 0.5;  % 电压最小值
        end
        buslist(busIndex) = {thisline(7 : 14)}; % 母线名称列表
    end
end
% 2.2.2. 得到发电机矩阵（11~21列先都赋0）Getting generator matrix(0 for column 11-21
% first)
disp('获得发电机矩阵...  Getting generator matrix...');
genMatrix = zeros(genNumber, 21);
genIndex = 0;
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if (length(thisline) < 65)  % 在长度不足65的字符串后面补足空格
                                % add space for shorter than 65
        thisline = [thisline, blanks(65 - length(thisline))];
    end
    if (strcmp(thisline(1 : 2), 'BE') || strcmp(thisline(1 : 2), 'BQ') || strcmp(thisline(1 : 2), 'BG') || strcmp(thisline(1 : 2), 'BS'))   % PV节点或平衡节点
        genIndex = genIndex + 1;
        busname = thisline(7 : 14);
        for jj = 1 : busNumber    % 发电机所连母线索引
            if (strcmp(buslist(jj), busname))
                genMatrix(genIndex, 1) = jj;
                break;
            end
        end
        if (~strcmp(thisline(43 : 47), blanks(5)))
            genMatrix(genIndex, 2) = str2double(thisline(43 : 47));   % 发电机实际有功出力Actual Pout
        else
            genMatrix(genIndex, 2) = 0.0;   % 发电机实际有功出力
        end
        genMatrix(genIndex, 3) = 0.0;   % 发电机实际无功出力，对PV节点在潮流计算过程中会修改，这里暂时先填写任意值
                                        %Actual Qout,meaningless for PV buses
        if (~strcmp(thisline(48 : 52), blanks(5)))
            genMatrix(genIndex, 4) = str2double(thisline(48 : 52));   % 发电机最大无功出力
        else
            genMatrix(genIndex, 4) = 9999.99;   % 发电机最大无功出力
        end
        if (~strcmp(thisline(53 : 57), blanks(5)))
            genMatrix(genIndex, 5) = str2double(thisline(53 : 57));   % 发电机最小无功出力
        else
            genMatrix(genIndex, 5) = 0.0;   % 发电机最小无功出力
        end
        if (~strcmp(thisline(58 : 61), blanks(4)))
            thisVoltage = str2double(thisline(58 : 61));
            while (thisVoltage > 2)
                thisVoltage = thisVoltage / 10;
            end
            genMatrix(genIndex, 6) = thisVoltage;   % 发电机整定机端母线电压幅值
        else
            genMatrix(genIndex, 6) = 1.0;   % 发电机整定机端母线电压幅值
        end
        genMatrix(genIndex, 7) = baseMVA;   % 发电机额定容量，这里暂时取全网基准容量
        genMatrix(genIndex, 8) = 1; % 发电机运行状态，默认为投入运行
        if (~strcmp(thisline(39 : 42), blanks(4)))
            genMatrix(genIndex, 9) = str2double(thisline(39 : 42));   % 发电机最大有功出力
        else
            genMatrix(genIndex, 9) = 9999.99;   % 发电机最大有功出力
        end
        genMatrix(genIndex, 10) = 0.0;  % 发电机最小有功出力
    end
end
% 2.2.3. 得到支路矩阵
disp('获得支路矩阵...   Getting branch matrix...');
branchMatrix = zeros(branchNumber, 13);
branchIndex = 0;
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if (length(thisline) < 72)  % 在长度不足72的字符串后面补足空格
        thisline = [thisline, blanks(72 - length(thisline))];
    end
    if (strcmp(thisline(1), 'L') || strcmp(thisline(1), 'T'))   % 线路或变压器line or transformer
        branchIndex = branchIndex + 1;
        busname1 = thisline(7 : 14);
        for jj = 1 : busNumber    % 支路起始端母线索引from and to buses
            if (strcmp(buslist(jj), busname1))
                branchMatrix(branchIndex, 2) = jj;
                break;
            end
        end
        busname2 = thisline(20 : 27);
        for jj = 1 : busNumber    % 支路终止端母线索引
            if (strcmp(buslist(jj), busname2))
                branchMatrix(branchIndex, 1) = jj;
                break;
            end
        end
        if (~strcmp(thisline(39 : 44), blanks(6)))
            value = thisline(39 : 44);
            branchMatrix(branchIndex, 3) = str2double(value);   % 支路电阻
            dotindex = findstr(value, '.');
            if (size(dotindex, 1) == 0 && size(dotindex, 2) == 0)
                branchMatrix(branchIndex, 3) = branchMatrix(branchIndex, 3) / 100000;
            end
        else
            branchMatrix(branchIndex, 3) = 0.0;   % 支路电阻
        end
        if (~strcmp(thisline(45 : 50), blanks(6)))
            value = thisline(45 : 50);
            branchMatrix(branchIndex, 4) = str2double(value);   % 支路电抗
            dotindex = findstr(value, '.');
            if (size(dotindex, 1) == 0 && size(dotindex, 2) == 0)
                branchMatrix(branchIndex, 4) = branchMatrix(branchIndex, 4) / 100000;
            end
        else
            branchMatrix(branchIndex, 4) = 0.0;   % 支路电抗
        end
        if (~strcmp(thisline(57 : 62), blanks(6)))
            branchMatrix(branchIndex, 5) = str2double(thisline(57 : 62)) * 2;   % 支路对地电纳，BPA中为B/2，故应将原数据乘以2
        else
            branchMatrix(branchIndex, 5) = 0.0;   % 支路电抗
        end
        % 交流线路或变压器长期、短期和紧急情况下的额定容量，BPA没有相应数据，暂时先用全网额定容量
        branchMatrix(branchIndex, 6) = baseMVA;
        branchMatrix(branchIndex, 7) = baseMVA;
        branchMatrix(branchIndex, 8) = baseMVA;
        % 支路非标准变比
        if (strcmp(thisline(1), 'L'))
            branchMatrix(branchIndex, 9) = 1.0; % 输电线路不存在非标准变比的问题
        elseif (strcmp(thisline(1), 'T'))
            vbase1 = str2double(thisline(15 : 18));
            vbase2 = str2double(thisline(28 : 31));
            vset1 = str2double(thisline(63 : 67));
            vset2 = str2double(thisline(68 : 72));
            kset = vset1 / vset2;
            kbase = vbase1 / vbase2;
            kpu = kset / kbase;
            % 修正因BPA中数据的FORTRAN格式造成的读取数据错误
            % Fixxing FORTRAN-caused dataform problem
            while kpu > 10
                kpu = kpu / 10;
            end
            while kpu < 0.1
                kpu = kpu * 10;
            end
            branchMatrix(branchIndex, 9) = 1 / kpu; % 变压器非标准变比的偏移量
        end
        branchMatrix(branchIndex, 10) = 0.0;    % 没有移相
        branchMatrix(branchIndex, 11) = 1;  % 支路运行状态，默认为运行
        branchMatrix(branchIndex, 12) = -360.0; % 两端母线最小相角差
        branchMatrix(branchIndex, 13) = 360.0; % 两端母线最大相角差
        
%         kpu = branchMatrix(branchIndex, 9);
%         branchMatrix(branchIndex, 3) = branchMatrix(branchIndex, 3) / kpu / kpu;
%         branchMatrix(branchIndex, 4) = branchMatrix(branchIndex, 4) / kpu / kpu;
%         branchMatrix(branchIndex, 5) = branchMatrix(branchIndex, 5) * kpu * kpu;
    end
end
% 2.2.4. 得到发电机发电成本矩阵
disp('获得发电机发电成本矩阵...   Getting gencost matrix...');
gencostMatrix = zeros(genNumber, 7);
% 2.3. 生成欲返回的电网对象及母线列表
mpc = struct('version', '2', 'baseMVA', baseMVA, 'bus', busMatrix, 'gen', genMatrix, 'branch', branchMatrix, 'areas', [], 'gencost', gencostMatrix);
disp(['成功将bpa格式数据文件',bpafile, '转换成matPower数据对象！',  'BPA file ', bpafile, ' converted to matPower struct successfully！']);
