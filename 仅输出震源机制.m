%% 提取断层数据、震源机制数据，并基于断层编号检索周围地震（仅导出走向、倾角、滑动角）
clear; close all; clc;

%% ——— 参数 ———
searchR_km      = 20;   % 检索半径（km）
minExportCount  = 20;   % 只有当某断层地震数 > 此阈值时，才导出 Excel

%% 设置导出目录
dataDir = fullfile(pwd, 'Data');
if ~exist(dataDir, 'dir')
    mkdir(dataDir);
end

%% 1. 读取断层表（无表头），并指定列名
T_faults = readtable('duanceng.xlsx', 'ReadVariableNames', false);
T_faults.Properties.VariableNames = {'断层名称','断层编号','经度','纬度','走向','倾角'};

%% 2. 读取震源机制表（无表头），并指定列名
T_events = readtable('focal_mechanism.txt', 'ReadVariableNames', false);
T_events.Properties.VariableNames = {'经度','纬度','走向','倾角','滑动角'};

%% 3. 初始化 Map，用来存放每个断层下的地震 table
faultDataMap = containers.Map('KeyType','char','ValueType','any');

%% 4. 获取唯一的断层“名称+编号”组合
T_faults.('组合键') = strcat(T_faults.("断层名称"), '_', string(T_faults.("断层编号")));
uniqueFaultKeys = unique(T_faults.('组合键'));

%% 5. 对每个唯一断层编号组合进行搜索匹配并导出
for i = 1:numel(uniqueFaultKeys)
    key = uniqueFaultKeys{i};
    parts = split(key, '_'); name = parts{1}; id = parts{2};

    sel = strcmp(T_faults.('断层名称'), name) & strcmp(string(T_faults.('断层编号')), id);
    subF = T_faults(sel, :);

    matched = table([],[],[],[],[], 'VariableNames', {'经度','纬度','走向','倾角','滑动角'});
    for j = 1:height(subF)
        lat0 = subF.('纬度')(j); lon0 = subF.('经度')(j);
        d_km = haversine(T_events.('纬度'), T_events.('经度'), lat0, lon0);
        idx = d_km <= searchR_km;
        if any(idx)
            matched = [matched; T_events(idx, :)];
        end
    end

    if ~isempty(matched)
        matched = unique(matched, 'rows');
    end
    faultDataMap(key) = matched;

    n = height(matched);
    if n >= minExportCount
        safeName = regexprep([name '_' id], '[\\/:*?"<>|]', '_');
        outFile = fullfile(dataDir, sprintf('%s_quakes.xlsx', safeName));
        % 仅导出走向、倾角、滑动角
        exportTable = matched(:, {'走向','倾角','滑动角'});
        writetable(exportTable, outFile, 'FileType','spreadsheet', 'WriteVariableNames', false);
        fprintf('导出文件：%s （共 %d 条记录，超过 %d）\n', outFile, n, minExportCount);
    else
        fprintf('断层“%s”编号 %s 地震数 %d ≤ %d，未导出。\n', name, id, n, minExportCount);
    end
end

%% 6. 将 Map 导出至 base 工作区
assignin('base', 'faultDataMap', faultDataMap);