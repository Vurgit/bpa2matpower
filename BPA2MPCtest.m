function [mpc] = BPA2MPCtest(bpafile, pfofile)
% BPA2MPC Convert BPA format file to Matpower mpc format file
% X类型母线（自动控制投切电容电抗器）暂未考虑
% buslist中母线名称格式为:母线名+额定电压等级,因为bpa中允许同一母线名对应多个电压等级
% 抽头可调节变压器的变比固定为设定变比
% 非对称线路（两侧电纳不相等）的情况按对称线路考虑，两侧电纳均取左侧电纳
% mpc中没有线路接地电导G和变压器等效电导G
% 线路并联高抗（L+支路）加到线路对地电纳中b=-2*Mvar/U^2（只能认为两侧高抗相等），也可以加到线路首末的母线上（第六列）感性为负。
% 如果提前用BPA计算了系统潮流，则两端直流线路按其指定输送功率等效为一正一负的两个负荷，注意直流线路可以传输无功（P，Q），多端直流线路没有考虑
% mpc.branch中第14列存回路标志，回路标志是数字或字符的ascll码
% L卡中线路的额定电流不是线电流，而是一个等效的虚拟电流，其值为sqrt（3）倍线电流（待定）
% case118.m, 由118bpa.dat转换的118mpc，用BPA计算的118bpa,dat, 三者结果相同
% By Shijun Tian, Xi'an Jiaotong University，tsjguoke@163.com, 2017/10/20
%第三版，在314行“获得支路矩阵”处，针对有时候buslist中母线名最后以“.”为结尾而支路
% 数据中的busname1 busname2名称结尾没有“.”的情况，或者是空格插入位置不正确导致的
% 无法从buslist中读取到支路起始母线的情况，把"."和" "全部删掉了。。。

% Define Default Values
defaultVmax = 1.052;
defaultVmin = 0.95;
defaultQgmax = 9999.0;
defaultQgmin = -9999.0;
defaultPgmin = 0.0;
baseMVA = 100;
% 读入BPA文件的所有内容
bpa_info = cell(50000,1); % 默认.dat文件最大行数
bpa_info(:) = {blanks(80)}; % 数据行最大列数为80
disp(['读入原始BPA潮流文件', bpafile, '的内容...']);
% 打开BPA潮流文件
fid = fopen(bpafile, 'r','n','GBK');
% 将所有内容读入到字符串集合中
ii = 1;
while (~feof(fid))
    newline = fgetl(fid);
    bpa_info{ii}(1:length(newline)) = newline;
    ii = ii + 1;
end
fclose(fid);%  关闭BPA潮流文件
bpa_info(ii:end) = []; %释放多余的空间
% 删除注释语句
temp=1;
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if ( strcmp(thisline(1), '.') || strcmp(thisline(1), ' ') )
        deleteLine(temp)=ii;
        temp=temp+1;
    end
end
bpa_info(deleteLine)=[];
% 统计某类型节点或支路数量
% 经统计nwsgdata.dat中TP=0，BX=0，E=0,LD=22,LM=0,+A=1
Num=0;
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if (strcmp(thisline(1:1), '+'))
        Num=Num+1;
    end
end
% 得到母线个数，支路个数，基准容量
busNumA = 0; % 交流母线个数
branchNumA = 0; % 交流支路个数
busNumD = 0; % 直流母线个数
branchNumD = 0; % 直流支路个数
disp('获得电网基本参数（母线个数，支路个数，基准容量）...');
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    pat = '/MVA_BASE';
    isbaseMVA = ~isempty(regexp(thisline, pat, 'match'));
    pat2 = '\d';
    % 获得基准容量
    if isbaseMVA
        baseMVAinfo = regexp(thisline, pat2, 'match');
        baseMVAinfo = cell2mat(baseMVAinfo);
        baseMVAinfo = num2str(baseMVAinfo);
        baseMVAinfo = strrep(baseMVAinfo, ' ', '');
        baseMVA = str2double(baseMVAinfo);
    end
    % 统计交流母线个数
    if (strcmp(thisline(1), 'B') &&  ~strcmp(thisline(2), 'D') && ~strcmp(thisline(2), 'M'))
        busNumA = busNumA + 1;
    end
    % 统计交流支路个数
    if (strcmp(thisline(1:2), 'L ') || strcmp(thisline(1), 'T') || strcmp(thisline(1), 'E') )
        branchNumA = branchNumA + 1;
    end
    % 统计直流母线个数
    if (strcmp(thisline(1:2), 'BD') ||  strcmp(thisline(1:2), 'BM'))
        busNumD = busNumD + 1;
    end
    % 统计直流支路个数
    if (strcmp(thisline(1:2), 'LD') || strcmp(thisline(1:2), 'LM'))
        branchNumD = branchNumD + 1;
    end
end
% 母线名称可能出现汉字，为保证字符长度对应bpa中的长度，要在汉字后面补充空格
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if ( ~strcmp(thisline(1), '(') && ~strcmp(thisline(1), '/') && ~strcmp(thisline(1), '>') ) %排除控制行，所有包含母线名称的数据行都是7：14
        temp = unicode2native(thisline(7:14),'GBK');
        numChn = length(temp)-8;% 母线名中包含的中文字符数 0<=numChn<=4
        thisline=[thisline(1:14-numChn),blanks(numChn),thisline(15-numChn:end)];
    end
    if (strcmp(thisline(1), 'L') || strcmp(thisline(1), 'E') || strcmp(thisline(1), 'T')|| strcmp(thisline(1), 'R')) % 和支路相关的行
        temp = unicode2native(thisline(20:27),'GBK');
        numChn = length(temp)-8;% 母线名2中包含的中文字符数 0<=numChn<=4
        thisline=[thisline(1:27-numChn),blanks(numChn),thisline(28-numChn:end)];
    end
    if (strcmp(thisline(1:2), 'BD') || strcmp(thisline(1:2), 'BM')) % 直流母线所连的换流节点
        temp = unicode2native(thisline(51:58),'GBK');
        numChn = length(temp)-8;% 母线名中包含的中文字符数 0<=numChn<=4
        thisline=[thisline(1:58-numChn),blanks(numChn),thisline(59-numChn:end)];
    end
    bpa_info(ii) = {thisline};
end
%% 处理zone
temp=0;
zonelist={};
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if ( strcmp(thisline(1), 'B') && ~strcmp(thisline(19 : 20), blanks(2)) ) %交直流节点且zone非空
        temp = temp + 1;
        zonelist(temp) = {thisline(19 : 20)};
    end
end
zonelist = unique(zonelist);
% 2.2. 得到母线矩阵，发电机矩阵，支路矩阵，母线列表
%% 2.2.1. 得到母线矩阵和母线名称列表
busNum=busNumA+busNumD;
busMatrix = zeros(busNum, 13);
% buslist = cell(busNum, 1);
busStrList = cell(busNum, 1);
busKVList = zeros(busNum, 1);
busIndex = 0;
disp('获得母线矩阵和母线名称列表...');
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if ( strcmp(thisline(1), 'B') ) %属于交直流节点
        busIndex = busIndex + 1;
        busStrList(busIndex) = {strrep(thisline(7 : 12), ' ', '')}; % 母线名称列表中的前一部分
        busKVList(busIndex) = str2double(strrep(thisline(15 : 18), ' ', '')); % 母线名称中的电压等级
        busMatrix(busIndex, 1) = busIndex;  % 母线编号
        switch thisline(2)  % 母线类型
            case {' ', 'T', 'C', 'V', 'F', 'J'}   % PQ节点
                busMatrix(busIndex, 2) = 1;
            case {'D', 'M'}   % 直流母线认为是PQ节点
                busMatrix(busIndex, 2) = 1;
            case {'E', 'Q', 'G', 'K', 'L'}    % PV节点
                busMatrix(busIndex, 2) = 2;
            case 'S'    % 平衡节点
                busMatrix(busIndex, 2) = 3;
        end
        busMatrix(busIndex, 7) = 9999;   % 母线所在area索引，matpower要求正整数
        busMatrix(busIndex, 8) = 1.0;   % 默认母线电压值（对PQ节点pf计算时无意义）
        busMatrix(busIndex, 11) = 9999; %母线所在zone索引，格式A2，matpower正整数
        if (~strcmp(thisline(19 : 20), blanks(2)))
            zonename = thisline(19 : 20); % zone名称（本程序暂不能处理zone有汉字的情况）
            zoneIndex = find(strcmp(zonelist,zonename)); % zone编号
            busMatrix(busIndex, 11) = zoneIndex;
        end
        if ( ~strcmp(thisline(2), 'D') && ~strcmp(thisline(2), 'M') ) % 是交流节点
            if (~strcmp(thisline(21 : 25), blanks(5)))
                busMatrix(busIndex, 3) = str2double(thisline(21 : 25));   % 有功负荷F5.0，默认值0
            end
            if (~strcmp(thisline(26 : 30), blanks(5)))
                busMatrix(busIndex, 4) = str2double(thisline(26 : 30));   % 无功负荷F5.0，默认值0
            end
            if (~strcmp(thisline(31 : 34), blanks(4)))
                busMatrix(busIndex, 5) = str2double(thisline(31 : 34));   % 对地电导F4.0，默认值0（用额定电压下有功来表示）
            end
            if (~strcmp(thisline(35 : 38), blanks(4)))
                busMatrix(busIndex, 6) = str2double(thisline(35 : 38));   % 对地电纳F4.0，默认值0（用额定电压下无功来表示，容性为正）
            end
            if (~strcmp(thisline(58 : 61), blanks(4)))
                busMatrix(busIndex, 8) = str2double(thisline(58 : 61));   % 母线电压值F4.3,只对PV，平衡节点有意义，PQ节点在潮流计算过程中会修改
            end
            busMatrix(busIndex, 9) = 0.0; % 母线默认相角值，除平衡节点外，其余会在潮流计算中修改
            if (~strcmp(thisline(62 : 65), blanks(4)) && busMatrix(busIndex, 2)==3)
                busMatrix(busIndex, 9) = str2double(thisline(62 : 65));  % 平衡节点相角值F4.1
            end
            busMatrix(busIndex, 10) = str2double(thisline(15 : 18));  % 母线电压等级F4.0
            busMatrix(busIndex, 12) = defaultVmax;  % 默认电压最大值
            if (~strcmp(thisline(58 : 61), blanks(4)) && busMatrix(busIndex, 2)==1)
                busMatrix(busIndex, 12) = str2double(thisline(58 : 61));  % PQ节点电压最大值F4.3
            end
            busMatrix(busIndex, 13) = defaultVmin;  % 默认电压最小值F4.3
            if (~strcmp(thisline(62 : 65), blanks(4)) && busMatrix(busIndex, 2)~=3)
                busMatrix(busIndex, 13) = str2double(thisline(62 : 65));  % 非平衡节点该位置存储电压最小值F4.3
            end
        else ( strcmp(thisline(1:2), 'BD') || strcmp(thisline(1:2), 'BM')); % 直流母线
            %直流母线是PQ节点，PD,QD,GS,BS,theta=0
            busMatrix(busIndex, 10) = str2double(thisline(15 : 18));  % 母线电压等级,整流/逆变节点交流侧电压
            busMatrix(busIndex, 12) = 2;  % 由于直流母线均由抽头可调的换流变压器接入换流节点，因此直流母线交流侧电压不做限制
            busMatrix(busIndex, 13) = 0;  % 默认电压最小值
        end
    end
    if ( strcmp(thisline(1:2), '+A')) % 延续节点，恒电流和恒功率负荷加到PD，QD中，恒阻抗负荷加到GS，BS中
        busnameStr1 = strrep(thisline(7 : 12), ' ', ''); % 延续节点名称
        busnameKV1 = str2double(strrep(thisline(15 : 18), ' ', ''));
        fbus = find(strcmp(busStrList,busnameStr1) & busKVList == busnameKV1); % 母线编号
        if (~strcmp(thisline(21 : 25), blanks(5)))
            busMatrix(fbus, 3) = busMatrix(fbus, 3) + str2double(thisline(21 : 25));   % 有功负荷(恒电流或恒功率MW)F5.0
        end
        if (~strcmp(thisline(26 : 30), blanks(5)))
            busMatrix(fbus, 4) = busMatrix(fbus, 4) + str2double(thisline(26 : 30));   % 无功负荷(恒电流或恒功率Mvar)F5.0
        end
        if (~strcmp(thisline(31 : 34), blanks(4)))
            busMatrix(fbus, 5) = busMatrix(fbus, 5) + str2double(thisline(31 : 34));   % 对地电导F4.0（恒阻抗负荷，用额定电压下有功来表示）
        end
        if (~strcmp(thisline(35 : 38), blanks(4)))
            busMatrix(fbus, 6) = busMatrix(fbus, 6) + str2double(thisline(35 : 38));   % 对地电纳F4.0（恒阻抗负荷，用额定电压下无功来表示，容性为正）
        end
    end
end
temp= find( busMatrix(:,8) > 10 ); % 根据母线电压给定值格式F4.3，电压大于10说明采用了省略小数点格式
busMatrix(temp,8) = busMatrix(temp,8)/1000;
temp= find( busMatrix(:,12) > 10 ); % Vmax类似
busMatrix(temp,8) = busMatrix(temp,8)/1000;
temp= find( busMatrix(:,13) > 10 ); % Vmin类似
busMatrix(temp,8) = busMatrix(temp,8)/1000;
temp = isnan(busMatrix) ;% 矩阵中出现nan的情况是bpa格式中该位置数据只有一个小数点
busMatrix(temp) = 0;
%% 得到发电机(调相机)矩阵
% 发电机节点一般为PV，Vtheta(BE,BQ,BG,BS)节点，但也有可能为PQ(B,BT,BV,BC,BF)节点（11~21列先都赋0）
disp('获得发电机矩阵...');
genMatrix = zeros(busNumA, 21);
genIndex = 0;
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if ( strcmp(thisline(1), 'B') && ~strcmp(thisline(2), 'D') && ~strcmp(thisline(2), 'M')) %非空，属于交流节点，非两端直流，非多端直流
        if (~strcmp(thisline(48 : 52),blanks(5)) || ~strcmp(thisline(39 : 42),blanks(4)) || ~strcmp(thisline(53 : 57),blanks(5)))%最大(安排)无功不为0，最大有功不为0，最小无功不为0
            genIndex = genIndex + 1;
            busnameStr = strrep(thisline(7 : 12), ' ', '');
            busnameKV = str2double(strrep(thisline(15 : 18), ' ', ''));
            genBus = find(strcmp(busStrList,busnameStr) & busKVList == busnameKV); % 发电机所连母线索引genBus
            genMatrix(genIndex, 1) = genBus;
            if (~strcmp(thisline(43 : 47), blanks(5)))
                genMatrix(genIndex, 2) = str2double(thisline(43 : 47));   % 发电机实际有功出力PgF5.0，默认为0
            end
            genMatrix(genIndex, 3) =0.0; % 默认发电机无功出力QgF5.0，对PV和平衡节点这个值没有意义，在潮流计算中会改变。
            genMatrix(genIndex, 4) = defaultQgmax; %默认发电机最大无功QmaxF5.0
            if (~strcmp(thisline(48 : 52), blanks(5)) && busMatrix(genBus,2)==1) %PQ节点
                genMatrix(genIndex, 3) = str2double(thisline(48 : 52));   % PQ节点该位置存储发电机安排无功F5.0
            elseif (~strcmp(thisline(48 : 52), blanks(5)))
                genMatrix(genIndex, 4) = str2double(thisline(48 : 52));   % 非PQ节点该位置存储发电机最大无功F5.0
            end
            genMatrix(genIndex, 5) = defaultQgmin; %默认发电机最小无功QminF5.0
            if (~strcmp(thisline(53 : 57), blanks(5)))
                genMatrix(genIndex, 5) = str2double(thisline(53 : 57));   % 发电机最小无功出力F5.0
            else
                genMatrix(genIndex, 5) = 0;
            end
            genMatrix(genIndex, 6) = 1.0;   % 发电机机端母线电压幅值F4.3,对PQ节点的发电机没意义。
            if (~strcmp(thisline(58 : 61), blanks(4)))
                genMatrix(genIndex, 6) = str2double(thisline(58 : 61));
            end
            genMatrix(genIndex, 7) = baseMVA;   % 发电机基准容量，这里暂时取全网基准容量
            genMatrix(genIndex, 8) = 1; % 发电机运行状态，默认为投入运行
            genMatrix(genIndex, 9) = defaultQgmax;   % 发电机默认最大有功出力
            if (~strcmp(thisline(39 : 42), blanks(4)))
                genMatrix(genIndex, 9) = str2double(thisline(39 : 42));   % 发电机最大有功出力F4.0
            end
            genMatrix(genIndex, 10) = defaultPgmin;  % 默认发电机最小有功出力(bpa无)
        end
    end
    if ( strcmp(thisline(1:2), '+A')) % 延续节点
        busnameStr = strrep(thisline(7 : 12), ' ', ''); % 延续节点名称
        busnameKV = str2num(thisline(15 : 18)); %#ok<*ST2NM>
        genBus = find(strcmp(busStrList,busnameStr) && busnameKV == busKVList); % 节点对应编号
        temp = find(genMatrix(:,1) == genBus); %节点对应发电机编号
        if (~strcmp(thisline(43 : 47), blanks(5)))
            genMatrix(temp, 2) = genMatrix(temp, 2) + str2double(thisline(43 : 47));   % 发电机有功出力PgF5.0
        end
        if (~strcmp(thisline(48 : 52), blanks(5)))
            genMatrix(temp, 3) = genMatrix(temp, 3) + str2double(thisline(48 : 52));   % 发电机无功出力PgF5.0
        end
    end
end
temp= find( genMatrix(:,6) > 10 ); % 根据母线电压给定值格式F4.3，电压大于10说明采用了省略小数点格式
genMatrix(temp,6) = genMatrix(temp,6)/1000;
temp =  isnan(genMatrix) ;% 矩阵中出现nan的情况是bpa格式中该数据只有一个小数点
genMatrix(temp) = 0;
genMatrix(genIndex+1:end,:) = [];
%% 发电或负荷的修改
% 目前只编写了PA，PZ卡对应的修改，其他卡暂未考虑
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if ( strcmp(thisline(1), 'P') ) %修改卡
        if (~strcmp(thisline(10 : 14), blanks(5)))
            factorPL = str2double(thisline(10 : 14));   % 负荷P修改因子
        else
            factorPL = 1;
        end
        if (~strcmp(thisline(10 : 14), blanks(5)))
            factorQL = str2double(thisline(16 : 20));   % 负荷Q修改因子
        else
            factorQL = factorPL;
        end
        if (~strcmp(thisline(22 : 26), blanks(5)))
            factorPG = str2double(thisline(22 : 26));   % 发电机有功P修改因子
        else
            factorPG = 1;
        end
        if (~strcmp(thisline(28 : 32), blanks(5)))
            factorQG = str2double(thisline(28 : 32));   % 发电机无功Q修改因子
        else
            factorQG = factorPG;
        end
        if ( strcmp(thisline(2), 'A') ) % 全网修改卡
            busMatrix(:,3) = factorPL*busMatrix(:,3);%PL
            busMatrix(:,4) = factorQL*busMatrix(:,4);%QL
            genMatrix(:,2) = factorPG*genMatrix(:,2);%PG
            genMatrix(:,3) = factorQG*genMatrix(:,3);%QG
        end
        if ( strcmp(thisline(2), 'Z') ) % 分区修改卡
            zonename = thisline(4:5);
            zoneIndex = find(strcmp(zonelist,zonename)); % 分区编号
            busIndex = find(busMatrix(:,11) == zoneIndex); % 分区内的所有母线
            busMatrix(busIndex,3) = factorPL*busMatrix(busIndex,3);%PL
            busMatrix(busIndex,4) = factorQL*busMatrix(busIndex,4);%QL
            temp = ismember(genMatrix(:,1),busIndex);
            genIndex = find(temp == 1);
            areaGen = sum(genMatrix(genIndex,2));
            genMatrix(genIndex,2) = factorPG*genMatrix(genIndex,2);%PG
            genMatrix(genIndex,3) = factorQG*genMatrix(genIndex,3);%QG
            areaGen = sum(genMatrix(genIndex,2));
        end
    end
end
%% 得到支路矩阵
disp('获得支路矩阵...');
branchMatrix = zeros(branchNumA, 14); % 第14列存回路标志
branchIndex = 0;
% buslist2=busStrList;
% for(kk=1:length(buslist2))
%     buslist2{kk,1}(find(buslist2{kk,1}==' '|buslist2{kk,1}=='.'))=[];%去除buslist2中所有的空格和“.”
% end
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if (strcmp(thisline(1:2), 'L ') || strcmp(thisline(1), 'E')  || strcmp(thisline(1), 'T'))   % 对称线路,不对称线路,变压器/调相机
        branchIndex = branchIndex + 1;
        fbusStr = strrep(thisline(7 : 12), ' ', '');
        fbusKV = str2num(thisline(15 : 18));
        branchMatrix(branchIndex, 1) = find(strcmp(busStrList,fbusStr)...
            & busKVList == fbusKV); % 支路始端母线编号
        tbusStr = strrep(thisline(20 : 25), ' ', '');
        tbusKV = str2num(thisline(28 : 31));
        branchMatrix(branchIndex, 2) = find(strcmp(busStrList,tbusStr)...
            & busKVList == tbusKV); % 支路末端母线编号
        if (~strcmp(thisline(39 : 44), blanks(6)))
            branchMatrix(branchIndex, 3) = str2double(thisline(39 : 44));   % 支路电阻F6.5,默认为0
        end
        branchMatrix(branchIndex, 4) =  0.0001; % 默认支路电抗F6.5
        if (~strcmp(thisline(45 : 50), blanks(6)))
            branchMatrix(branchIndex, 4) = str2double(thisline(45 : 50));   % 支路电抗F6.5
        end
        if (~strcmp(thisline(57 : 62), blanks(6)) && strcmp(thisline(1), 'T'))
            branchMatrix(branchIndex, 5) = str2double(thisline(57 : 62));   % 变压器支路对地电纳F6.5，默认为0，BPA中只加在左侧，mpc中将该数值/2加在两侧，且mpc中无对地电导
            %       NWSG中所有变压器无对地电纳
        elseif (~strcmp(thisline(57 : 62), blanks(6)))
            branchMatrix(branchIndex, 5) = str2double(thisline(57 : 62)) * 2;   % L ,E支路对地电纳F6.5，忽略不对称线路，BPA中该数值为B/2，故应将原数据乘以2
        end
        branchMatrix(branchIndex, 6) = 0.0; %默认Rate_A无限制
        if (~strcmp(thisline(34 : 37), blanks(4)) && strcmp(thisline(1), 'T'))
            branchMatrix(branchIndex, 6) = str2double(thisline(34 : 37)); %变压器额定容量MVAF4.0
        elseif (~strcmp(thisline(34 : 37), blanks(4)))
            branchMatrix(branchIndex, 6) = str2double(thisline(15 : 18))*str2double(thisline(34 : 37));   % 线路Rate_A=U*I(MVA)F4.0,(Sf = V .* conj(Yf * V))
        end
        branchMatrix(branchIndex, 7) = 0.0;  % Rate_B(MVA)
        branchMatrix(branchIndex, 8) = 0.0;  % Rate_C(MVA)
        branchMatrix(branchIndex, 9) = 0.0; % 默认非标准变比
        if (strcmp(thisline(1:2), 'T '))
            branchMatrix(branchIndex, 9) = 1.0; % 变压器默认非标准变比
            V1pu = str2double(thisline(63 : 67)) / str2double(thisline(15 : 18));% 分接头位置F5.2,母线电压等级F4.0
            V2pu = str2double(thisline(68 : 72)) / str2double(thisline(28 : 31));
            if V1pu > 10 % 大于10说明分接头位置采用了省略小数点的格式
                V1pu=V1pu/100;
            end
            if V2pu > 10
                V2pu=V2pu/100;
            end
            branchMatrix(branchIndex, 9) = V1pu / V2pu;  % 非标准变比（已用bpa118.dat验证）
        end
        branchMatrix(branchIndex, 10) = 0.0;    % 默认移相角
        if (strcmp(thisline(1:2), 'TP') && ~strcmp(thisline(63 : 67), blanks(5)))
            branchMatrix(branchIndex, 10) = str2double(thisline(63 : 67));  % 移相角F5.2
            if (branchMatrix(branchIndex, 10) > 1000) %采用了省略小数点格式
                branchMatrix(branchIndex, 10) = branchMatrix(branchIndex, 10)/100;
            end
        end
        branchMatrix(branchIndex, 11) = 1;  % 支路运行状态，默认为运行
        branchMatrix(branchIndex, 12) = -360.0; % 两端母线最小相角差
        branchMatrix(branchIndex, 13) = 360.0; % 两端母线最大相角差
        if (~strcmp(thisline(32), blanks(1))) %并联线路回路标志，格式A1，但为了简单此处认为回路标志是数字,若不是数字可以存ascll码
            branchMatrix(branchIndex, 14) = str2double(thisline(32));   % 将回路标志放在14列，默认为0
        end
    end
end
temp = find( branchMatrix(:,5) > 20 ); % bpa的数据格式F6.5决定了B/2小于10，因此B<20
branchMatrix(temp,5) = branchMatrix(temp,5)/100000;% 采用了省略小数点格式
temp = find( branchMatrix(:,3) > 10 | branchMatrix(:,3) < -10 );% 线路电阻r，格式F6.5.三绕组变压器等效电阻可能出现负值
branchMatrix(temp,3) = branchMatrix(temp,3)/100000;
temp = find( branchMatrix(:,4) > 10 | branchMatrix(:,4) < -10 );% 线路电抗x，格式F6.5.三绕组变压器等效电抗可能出现负值
branchMatrix(temp,4) = branchMatrix(temp,4)/100000;
temp =  isnan(branchMatrix) ;% 矩阵中出现nan的情况是bpa格式中该数据只有一个小数点
branchMatrix(temp) = 0;
%% 直流线路和线路高抗的处理
% 直流线路处理为负荷，加到直流母线上(假设直流潮流都是由电网向外输送)，将区域等效平衡机移到直流送端
% 线路高抗参数加到线路首末的母线上
DCout=0; %统计直流外送负荷
for ii = 1 : length(bpa_info)
    thisline = bpa_info{ii};
    if (strcmp(thisline(1:2), 'LD') && ~strcmp(thisline(57 : 61), blanks(5)))   % 两端直流，(多端直流没有安排功率，目前不考虑)
        fbusStrLD = strrep(strthisline(7 : 12), ' ', '');
        fbusKVLD = str2num(thisline(15 : 18));
        fbusLD = strcmp(busStrList,fbusStrLD) & busKVList == fbusKVLD; % 支路始端母线编号
        tbusStrLD = strrep(thisline(20 : 25), ' ', '');
        tbusKVLD = str2num(thisline(28 : 31));
        tbusLD = strcmp(busStrList,tbusStrLD) & busKVList == tbusKVLD;  % 支路末端母线编号
        temp = str2double(thisline(57 : 61)); % 安排的直流功率F5.1
        if (temp > 10000) % 采用了省略小数点的格式
            temp=temp/10;
        end
        busMatrix(fbusLD,3) = temp;
        busMatrix(tbusLD,3) = -temp;
        DCout=DCout+temp;
    end
    if (strcmp(thisline(1:2), 'L+') && ~strcmp(thisline(34 : 38), blanks(5)))
        fbusStrLP = strrep(thisline(7 : 12), ' ', '');
        fbusKVLP = str2num(thisline(15 : 18));
        fbusLP = find(strcmp(busStrList,fbusStrLP) & busKVList == fbusKVLP); % 支路始端母线编号
        tbusStrLP = strrep(thisline(20 : 25), ' ', '');
        tbusKVLP = str2num(thisline(28 : 31));
        tbusLP = find(strcmp(busStrList,tbusStrLP) & busKVList == tbusKVLP);  % 支路末端母线编号
        busMatrix(fbusLP,6) = busMatrix(fbusLP,6)-str2double(thisline(34 : 38)); % 左侧高抗Mvar值F5.0
        busMatrix(tbusLP,6) = busMatrix(tbusLP,6)-str2double(thisline(44 : 48)); % 右侧高抗Mvar值F5.0
    end
end
%% 得到发电机发电成本矩阵
disp('获得发电机发电成本矩阵...');
genNum=length(genMatrix(:,1));
gencostMatrix = zeros(genNum, 7);
gencostMatrix(:,1) = 2; %假设所有机组成本为1
gencostMatrix(:,4) = 2;
gencostMatrix(:,5) = 1;
% 生成mpc结构体
mpc = struct('version', '2', 'baseMVA', baseMVA, 'bus', busMatrix, 'gen', genMatrix, 'branch', ...
    branchMatrix, 'gencost', gencostMatrix, 'bus_name', {busStrList});
%%


% savecase('nwsg.m',mpc); %savecase会清除自定义的比如回路标识等数据。可改用matlab save代替
disp(['成功将bpa格式潮流数据文件 ', bpafile, ' 转换成matPower数据对象！']);

%% PFO文件读取，将PFO中节点电压幅值和角度信息加载到matpower数据里
if nargin>1
    pfo_info = cell(50000,1); % 默认.dat文件最大行数
    pfo_info(:) = {blanks(80)}; % 数据行最大列数为80
    disp(['读入原始BPA潮流输出PFO文件', pfofile, '的内容...']);
    % 打开BPA潮流文件
    fid = fopen(pfofile, 'r','n','GBK');
    % 将所有内容读入到字符串集合中
    ii = 1;
    while (~feof(fid))
        newline = fgetl(fid);
        pfo_info{ii}(1:length(newline)) = newline;
        ii = ii + 1;
    end
    fclose(fid);%  关闭BPA潮流文件
    pfo_info(ii:end) = []; %释放多余的空间
    startline = 1;
    finishline = 2;
    
    for ii = 1 : length(pfo_info)
        thisline = pfo_info{ii};
        if strcmp(thisline(1:11),'*  节点相关数据列表')
            startline = ii + 4;
        end
    end
    
    for ii = startline : length(pfo_info)
        thisline = pfo_info{ii};
        if strcmp(thisline(1 : 11),'          整')
            finishline = ii - 2;
        end
    end
    pfo_info = pfo_info(startline : finishline, 1);
    
    for ii = 1 : length(pfo_info)
        thislinePFO = pfo_info{ii};
        Va_pfo = str2double(thislinePFO(:, (end - 5) : end));
        Vm_pfo = str2double(thislinePFO(:, (end - 11) : (end - 7)));
        busStrPFO = strrep(thislinePFO(:, 4 : 8), ' ', '');
        busKVPFO = str2num(thislinePFO(:, 9 : 15));
        busMatch = find(strcmp(busStrList,busStrPFO) & busKVList == busKVPFO);
        if isempty(busMatch)
            error(['PFO文件中的节点 ', busStrPFO, ' ', num2str(busKVPFO), ...
                ' 没找到对应的节点']) 
        end
        mpc.bus(busMatch, 9) = Va_pfo;
        mpc.bus(busMatch, 8) = Vm_pfo;
    end
    disp(['成功将bpa格式PFO数据文件 ', pfofile,...
        ' 中的电压信息加载至matPower数据对象中！']);
end
[groups, isolated] = find_islands(mpc); % 直流断开后会形成孤岛系统
% %[groups, isolated] = case_info(mpc);
mpc = extract_islands(mpc, groups, 1); % 主系统的mpc，提取孤岛后，节点编号不连续(默认升序)，bus_name也不对应了
% islandsBus = cell2mat(groups(2:end)); %主系统外孤岛包含节点
% %mpc.bus_name(islandsBus) = []; % 主系统外孤岛节点对应的母线名

%% 这一段是源程序中，在mpc.bus中去掉孤岛节点，并把所有的孤岛节点母线名在bus_name中变为空集

mpc = ext2int(mpc);
end
