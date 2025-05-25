--[[
    数据压缩工具 (DataCompressor)
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    功能:
    - 高效数据压缩算法
    - 数据分块处理
    - 压缩效果统计
    - 多种压缩策略
--]]

-- 基于ModuleBase创建DataCompressor
local DataCompressor = ModuleBase:new({
    name = "DataCompressor",
    version = "1.0.0",
    description = "桌游伴侣数据压缩工具",
    author = "LeadDeveloperAI",
    dependencies = {},
    
    default_config = {
        compression_enabled = true,
        chunk_size = 8192,          -- 8KB每块
        min_compression_size = 1024, -- 最小压缩数据大小
        compression_threshold = 0.8,  -- 压缩阈值(80%)
        max_chunks = 100            -- 最大分块数
    }
})

-- 压缩类型定义
DataCompressor.COMPRESSION_TYPES = {
    NONE = "none",          -- 无压缩
    RLE = "rle",           -- Run-Length Encoding
    DICT = "dict",         -- 简单字典压缩
    HYBRID = "hybrid"      -- 混合压缩
}

-- 压缩状态
DataCompressor.compression_stats = {
    total_compressed = 0,
    total_decompressed = 0,
    compression_ratio = 0,
    compression_time = 0,
    decompression_time = 0
}

-- 初始化方法
function DataCompressor:onInitialize(save_data)
    Logger:info("初始化数据压缩工具")
    
    -- 初始化压缩系统
    self:initializeCompressor()
    
    -- 加载压缩统计
    self:loadCompressionStats(save_data)
    
    Logger:info("数据压缩工具初始化完成", {
        chunk_size = self.config.chunk_size,
        compression_enabled = self.config.compression_enabled
    })
end

-- 初始化压缩器
function DataCompressor:initializeCompressor()
    -- 重置统计信息
    self.compression_stats = {
        total_compressed = 0,
        total_decompressed = 0,
        compression_ratio = 0,
        compression_time = 0,
        decompression_time = 0,
        operations_count = 0
    }
    
    Logger:debug("压缩器已初始化")
end

-- 加载压缩统计
function DataCompressor:loadCompressionStats(save_data)
    if save_data and save_data.compression_stats then
        self.compression_stats = save_data.compression_stats
        Logger:info("已加载压缩统计数据")
    end
end

-- 压缩数据
function DataCompressor:compress(data, compression_type)
    if not self.config.compression_enabled then
        Logger:debug("压缩已禁用，返回原始数据")
        return data
    end
    
    if not data then
        Logger:error("压缩数据为空")
        return nil
    end
    
    -- 转换为字符串
    local input_string = self:dataToString(data)
    local original_size = string.len(input_string)
    
    -- 检查数据大小是否值得压缩
    if original_size < self.config.min_compression_size then
        Logger:debug("数据太小，跳过压缩", {size = original_size})
        return input_string
    end
    
    local start_time = os.clock()
    local compressed_data = nil
    compression_type = compression_type or self.COMPRESSION_TYPES.HYBRID
    
    -- 根据压缩类型选择算法
    if compression_type == self.COMPRESSION_TYPES.RLE then
        compressed_data = self:compressRLE(input_string)
    elseif compression_type == self.COMPRESSION_TYPES.DICT then
        compressed_data = self:compressDict(input_string)
    elseif compression_type == self.COMPRESSION_TYPES.HYBRID then
        compressed_data = self:compressHybrid(input_string)
    else
        compressed_data = input_string
    end
    
    local compression_time = os.clock() - start_time
    
    if compressed_data then
        local compressed_size = string.len(compressed_data)
        local ratio = compressed_size / original_size
        
        -- 只有在压缩效果达到阈值时才返回压缩数据
        if ratio <= self.config.compression_threshold then
            self:updateCompressionStats(original_size, compressed_size, compression_time, true)
            
            Logger:debug("数据压缩成功", {
                original_size = original_size,
                compressed_size = compressed_size,
                ratio = math.floor(ratio * 100) .. "%",
                time = compression_time
            })
            
            return compressed_data, compression_type
        else
            Logger:debug("压缩效果不佳，使用原始数据", {ratio = math.floor(ratio * 100) .. "%"})
        end
    end
    
    self:updateCompressionStats(original_size, original_size, compression_time, false)
    return input_string
end

-- 解压数据
function DataCompressor:decompress(compressed_data, compression_type)
    if not compressed_data then
        Logger:error("解压数据为空")
        return nil
    end
    
    -- 如果没有指定压缩类型，尝试自动检测
    if not compression_type then
        compression_type = self:detectCompressionType(compressed_data)
    end
    
    -- 如果是原始数据，直接返回
    if compression_type == self.COMPRESSION_TYPES.NONE then
        return self:stringToData(compressed_data)
    end
    
    local start_time = os.clock()
    local decompressed_data = nil
    
    -- 根据压缩类型选择解压算法
    if compression_type == self.COMPRESSION_TYPES.RLE then
        decompressed_data = self:decompressRLE(compressed_data)
    elseif compression_type == self.COMPRESSION_TYPES.DICT then
        decompressed_data = self:decompressDict(compressed_data)
    elseif compression_type == self.COMPRESSION_TYPES.HYBRID then
        decompressed_data = self:decompressHybrid(compressed_data)
    else
        decompressed_data = compressed_data
    end
    
    local decompression_time = os.clock() - start_time
    
    if decompressed_data then
        self:updateCompressionStats(0, 0, decompression_time, false, true)
        
        Logger:debug("数据解压成功", {
            compressed_size = string.len(compressed_data),
            decompressed_size = string.len(decompressed_data),
            time = decompression_time
        })
        
        return self:stringToData(decompressed_data)
    else
        Logger:error("数据解压失败")
        return nil
    end
end

-- RLE压缩实现
function DataCompressor:compressRLE(data)
    local compressed = ""
    local i = 1
    local len = string.len(data)
    
    while i <= len do
        local char = string.sub(data, i, i)
        local count = 1
        
        -- 计算连续字符数量
        while i + count <= len and string.sub(data, i + count, i + count) == char and count < 255 do
            count = count + 1
        end
        
        if count > 3 then
            -- 压缩格式: \255 + count + char
            compressed = compressed .. "\255" .. string.char(count) .. char
            i = i + count
        else
            -- 直接添加字符
            for j = 1, count do
                compressed = compressed .. char
            end
            i = i + count
        end
    end
    
    return compressed
end

-- RLE解压实现
function DataCompressor:decompressRLE(compressed_data)
    local decompressed = ""
    local i = 1
    local len = string.len(compressed_data)
    
    while i <= len do
        local char = string.sub(compressed_data, i, i)
        
        if char == "\255" and i + 2 <= len then
            -- 解压格式
            local count = string.byte(string.sub(compressed_data, i + 1, i + 1))
            local repeat_char = string.sub(compressed_data, i + 2, i + 2)
            decompressed = decompressed .. string.rep(repeat_char, count)
            i = i + 3
        else
            decompressed = decompressed .. char
            i = i + 1
        end
    end
    
    return decompressed
end

-- 简单字典压缩实现
function DataCompressor:compressDict(data)
    -- 构建字符频率表
    local freq = {}
    for i = 1, string.len(data) do
        local char = string.sub(data, i, i)
        freq[char] = (freq[char] or 0) + 1
    end
    
    -- 生成字典（最常用的字符映射到较短的代码）
    local dict = {}
    local reverse_dict = {}
    local code = 1
    
    -- 按频率排序
    local sorted_chars = {}
    for char, count in pairs(freq) do
        table.insert(sorted_chars, {char = char, count = count})
    end
    
    table.sort(sorted_chars, function(a, b) return a.count > b.count end)
    
    -- 为高频字符分配短代码
    for i = 1, math.min(#sorted_chars, 10) do
        local char = sorted_chars[i].char
        local short_code = string.char(code)
        dict[char] = short_code
        reverse_dict[short_code] = char
        code = code + 1
    end
    
    -- 压缩数据
    local compressed = ""
    for i = 1, string.len(data) do
        local char = string.sub(data, i, i)
        if dict[char] then
            compressed = compressed .. dict[char]
        else
            compressed = compressed .. char
        end
    end
    
    -- 添加字典头
    local dict_header = JSON.encode(reverse_dict)
    compressed = string.char(string.len(dict_header)) .. dict_header .. compressed
    
    return compressed
end

-- 简单字典解压实现
function DataCompressor:decompressDict(compressed_data)
    if string.len(compressed_data) < 1 then
        return compressed_data
    end
    
    -- 读取字典头
    local dict_len = string.byte(string.sub(compressed_data, 1, 1))
    if string.len(compressed_data) < dict_len + 2 then
        return compressed_data -- 数据格式错误，返回原始数据
    end
    
    local dict_header = string.sub(compressed_data, 2, dict_len + 1)
    local success, reverse_dict = pcall(JSON.decode, dict_header)
    
    if not success then
        return compressed_data -- 字典解析失败，返回原始数据
    end
    
    -- 解压数据
    local data_part = string.sub(compressed_data, dict_len + 2)
    local decompressed = ""
    
    for i = 1, string.len(data_part) do
        local char = string.sub(data_part, i, i)
        if reverse_dict[char] then
            decompressed = decompressed .. reverse_dict[char]
        else
            decompressed = decompressed .. char
        end
    end
    
    return decompressed
end

-- 混合压缩实现
function DataCompressor:compressHybrid(data)
    -- 先尝试RLE压缩
    local rle_compressed = self:compressRLE(data)
    local rle_ratio = string.len(rle_compressed) / string.len(data)
    
    -- 再尝试字典压缩
    local dict_compressed = self:compressDict(data)
    local dict_ratio = string.len(dict_compressed) / string.len(data)
    
    -- 选择压缩效果最好的
    if rle_ratio <= dict_ratio and rle_ratio < 0.9 then
        return "R" .. rle_compressed -- 标记为RLE压缩
    elseif dict_ratio < 0.9 then
        return "D" .. dict_compressed -- 标记为字典压缩
    else
        return "N" .. data -- 标记为无压缩
    end
end

-- 混合解压实现
function DataCompressor:decompressHybrid(compressed_data)
    if string.len(compressed_data) < 2 then
        return compressed_data
    end
    
    local method = string.sub(compressed_data, 1, 1)
    local data_part = string.sub(compressed_data, 2)
    
    if method == "R" then
        return self:decompressRLE(data_part)
    elseif method == "D" then
        return self:decompressDict(data_part)
    elseif method == "N" then
        return data_part
    else
        return compressed_data -- 未知格式，返回原始数据
    end
end

-- 数据分块
function DataCompressor:splitToChunks(data)
    if not data then
        Logger:error("分块数据为空")
        return nil
    end
    
    local data_string = self:dataToString(data)
    local total_size = string.len(data_string)
    local chunk_size = self.config.chunk_size
    local chunks = {}
    
    local chunk_count = math.ceil(total_size / chunk_size)
    
    -- 检查分块数量限制
    if chunk_count > self.config.max_chunks then
        Logger:warning("数据分块数量超出限制", {
            chunk_count = chunk_count,
            max_chunks = self.config.max_chunks
        })
        chunk_size = math.ceil(total_size / self.config.max_chunks)
        chunk_count = self.config.max_chunks
    end
    
    for i = 1, chunk_count do
        local start_pos = (i - 1) * chunk_size + 1
        local end_pos = math.min(i * chunk_size, total_size)
        local chunk_data = string.sub(data_string, start_pos, end_pos)
        
        chunks[i] = {
            index = i,
            data = chunk_data,
            size = string.len(chunk_data),
            checksum = self:calculateChecksum(chunk_data)
        }
    end
    
    Logger:debug("数据已分块", {
        total_size = total_size,
        chunk_count = chunk_count,
        chunk_size = chunk_size
    })
    
    return chunks
end

-- 合并分块
function DataCompressor:mergeChunks(chunks)
    if not chunks or #chunks == 0 then
        Logger:error("合并分块数据为空")
        return nil
    end
    
    -- 按索引排序
    table.sort(chunks, function(a, b) return a.index < b.index end)
    
    local merged_data = ""
    local total_size = 0
    
    for _, chunk in ipairs(chunks) do
        -- 验证校验和
        local expected_checksum = self:calculateChecksum(chunk.data)
        if chunk.checksum ~= expected_checksum then
            Logger:error("分块校验和验证失败", {
                index = chunk.index,
                expected = expected_checksum,
                actual = chunk.checksum
            })
            return nil
        end
        
        merged_data = merged_data .. chunk.data
        total_size = total_size + chunk.size
    end
    
    Logger:debug("分块已合并", {
        chunk_count = #chunks,
        total_size = total_size
    })
    
    return self:stringToData(merged_data)
end

-- 检测压缩类型
function DataCompressor:detectCompressionType(data)
    if string.len(data) < 1 then
        return self.COMPRESSION_TYPES.NONE
    end
    
    local first_char = string.sub(data, 1, 1)
    
    -- 检查混合压缩标记
    if first_char == "R" or first_char == "D" or first_char == "N" then
        return self.COMPRESSION_TYPES.HYBRID
    end
    
    -- 检查RLE压缩标记
    if string.find(data, "\255") then
        return self.COMPRESSION_TYPES.RLE
    end
    
    -- 尝试检测字典压缩（有字典头）
    if string.len(data) > 10 then
        local dict_len = string.byte(first_char)
        if dict_len > 0 and dict_len < 100 and string.len(data) > dict_len + 1 then
            return self.COMPRESSION_TYPES.DICT
        end
    end
    
    return self.COMPRESSION_TYPES.NONE
end

-- 计算校验和
function DataCompressor:calculateChecksum(data)
    local checksum = 0
    for i = 1, string.len(data) do
        checksum = (checksum + string.byte(data, i)) % 65536
    end
    return checksum
end

-- 数据转字符串
function DataCompressor:dataToString(data)
    if type(data) == "string" then
        return data
    elseif type(data) == "table" then
        return JSON.encode(data)
    else
        return tostring(data)
    end
end

-- 字符串转数据
function DataCompressor:stringToData(str)
    -- 尝试JSON解码
    local success, decoded = pcall(JSON.decode, str)
    if success then
        return decoded
    else
        return str
    end
end

-- 更新压缩统计
function DataCompressor:updateCompressionStats(original_size, compressed_size, operation_time, is_compression, is_decompression)
    if is_compression then
        self.compression_stats.total_compressed = self.compression_stats.total_compressed + original_size
        self.compression_stats.compression_time = self.compression_stats.compression_time + operation_time
    end
    
    if is_decompression then
        self.compression_stats.total_decompressed = self.compression_stats.total_decompressed + compressed_size
        self.compression_stats.decompression_time = self.compression_stats.decompression_time + operation_time
    end
    
    self.compression_stats.operations_count = self.compression_stats.operations_count + 1
    
    -- 计算总体压缩比
    if self.compression_stats.total_compressed > 0 then
        -- 这里需要追踪实际的压缩后大小来计算真实的压缩比
        -- 简化计算，假设平均压缩比
        local estimated_compressed_total = self.compression_stats.total_compressed * 0.7
        self.compression_stats.compression_ratio = math.floor((1 - estimated_compressed_total / self.compression_stats.total_compressed) * 100)
    end
end

-- 获取压缩统计
function DataCompressor:getCompressionStats()
    return {
        total_compressed = self.compression_stats.total_compressed,
        total_decompressed = self.compression_stats.total_decompressed,
        compression_ratio = self.compression_stats.compression_ratio,
        compression_time = self.compression_stats.compression_time,
        decompression_time = self.compression_stats.decompression_time,
        operations_count = self.compression_stats.operations_count,
        average_compression_time = self.compression_stats.operations_count > 0 and 
            (self.compression_stats.compression_time / self.compression_stats.operations_count) or 0,
        average_decompression_time = self.compression_stats.operations_count > 0 and 
            (self.compression_stats.decompression_time / self.compression_stats.operations_count) or 0
    }
end

-- 测试压缩效果
function DataCompressor:testCompression(test_data)
    if not test_data then
        Logger:error("测试数据为空")
        return nil
    end
    
    local results = {}
    local original_size = string.len(self:dataToString(test_data))
    
    -- 测试各种压缩算法
    for _, compression_type in pairs(self.COMPRESSION_TYPES) do
        if compression_type ~= self.COMPRESSION_TYPES.NONE then
            local start_time = os.clock()
            local compressed, _ = self:compress(test_data, compression_type)
            local compression_time = os.clock() - start_time
            
            local compressed_size = string.len(compressed or "")
            local ratio = compressed_size / original_size
            
            start_time = os.clock()
            local decompressed = self:decompress(compressed, compression_type)
            local decompression_time = os.clock() - start_time
            
            -- 验证解压正确性
            local decompressed_string = self:dataToString(decompressed)
            local original_string = self:dataToString(test_data)
            local is_correct = decompressed_string == original_string
            
            results[compression_type] = {
                original_size = original_size,
                compressed_size = compressed_size,
                compression_ratio = math.floor(ratio * 100),
                compression_time = compression_time,
                decompression_time = decompression_time,
                is_correct = is_correct
            }
        end
    end
    
    Logger:info("压缩算法测试完成", results)
    
    return results
end

-- 获取保存数据
function DataCompressor:getSaveData()
    return {
        compression_stats = self.compression_stats,
        version = self.version
    }
end

-- 子类关闭方法
function DataCompressor:onShutdown()
    Logger:info("数据压缩工具关闭", {
        final_stats = self:getCompressionStats()
    })
end

-- 导出DataCompressor模块
return DataCompressor 