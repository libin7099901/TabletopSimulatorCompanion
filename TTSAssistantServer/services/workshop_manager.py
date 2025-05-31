#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - Workshop管理器
负责扫描TTS数据目录，管理规则书元数据
"""

import os
import json
import re
import glob
import pathlib
from typing import Dict, List, Optional, Any, Union
import config as cfg
from services.rulebook_manager import RulebookManager

class WorkshopManager:
    """管理TTS Workshop数据和规则书元数据"""
    
    def __init__(self):
        """初始化Workshop管理器"""
        self.rulebook_manager = RulebookManager()
        self.processed_mods_file = cfg.PROCESSED_MODS_FILE
        self.processed_mods = self._load_processed_mods()
        
    def _load_processed_mods(self) -> Dict:
        """从JSON文件加载已处理的Mod数据"""
        if os.path.exists(self.processed_mods_file):
            try:
                with open(self.processed_mods_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except json.JSONDecodeError:
                print(f"警告: {self.processed_mods_file} 解析失败，将创建新文件")
        return {}
    
    def _save_processed_mods(self):
        """保存已处理的Mod数据到JSON文件"""
        # 确保目录存在
        os.makedirs(os.path.dirname(self.processed_mods_file), exist_ok=True)
        
        with open(self.processed_mods_file, 'w', encoding='utf-8') as f:
            json.dump(self.processed_mods, f, ensure_ascii=False, indent=2)
    
    def slugify(self, text: str) -> str:
        """将文本转换为URL友好的格式"""
        # 移除非字母数字字符
        text = re.sub(r'[^\w\s-]', '', text.lower())
        # 将空格替换为下划线
        text = re.sub(r'[\s]+', '_', text)
        return text
    
    def scan_all_tts_data(self):
        """扫描TTS Workshop数据，查找游戏和规则书(PDF)"""
        if not cfg.TTS_DATA_DIRECTORY or not os.path.exists(cfg.TTS_DATA_DIRECTORY):
            print(f"错误: TTS数据目录不存在或未配置: {cfg.TTS_DATA_DIRECTORY}")
            return
        
        workshop_file_infos_path = os.path.join(cfg.TTS_DATA_DIRECTORY, "Mods", "Workshop", "WorkshopFileInfos.json")
        
        if not os.path.exists(workshop_file_infos_path):
            print(f"错误: WorkshopFileInfos.json 未找到于: {workshop_file_infos_path}")
            # 作为后备，可以考虑扫描Saves目录，或者只依赖于已有的processed_mods.json
            # 目前，如果核心的Workshop清单不存在，我们将中止扫描以避免不完整的处理
            return
        
        print(f"正在从 {workshop_file_infos_path} 读取已下载的工坊物品信息...")
        try:
            with open(workshop_file_infos_path, 'r', encoding='utf-8') as f:
                workshop_items = json.load(f)
        except json.JSONDecodeError:
            print(f"错误: 解析 WorkshopFileInfos.json 失败。文件可能已损坏。")
            return
        except Exception as e:
            print(f"读取 WorkshopFileInfos.json 时发生未知错误: {e}")
            return
        
        scanned_games_count = 0
        for item in workshop_items:
            game_name = item.get("Name")
            game_json_path = item.get("Directory") # 这是指向单个mod的json文件路径
            
            if not game_name or not game_json_path:
                print(f"警告: WorkshopFileInfos.json 中的项目缺少名称或目录: {item}")
                continue
            
            # 确保路径是绝对的并且使用正确的系统分隔符
            # "Directory" 键中的路径可能已经是绝对的，并且可能包含混合的分隔符
            if not os.path.isabs(game_json_path):
                 # 如果不是绝对路径，我们假定它相对于TTS_DATA_DIRECTORY下的某个位置，
                 # 但 WorkshopFileInfos.json 通常包含绝对路径或相对于其自身位置的路径。
                 # 为简单起见，我们先打印警告，后续可能需要更复杂的路径解析逻辑。
                 print(f"警告: 游戏 '{game_name}' 的路径 '{game_json_path}' 不是绝对路径，可能无法正确定位。")
                 # 尝试将其相对于WorkshopFileInfos.json的目录进行解析
                 game_json_path = os.path.join(os.path.dirname(workshop_file_infos_path), game_json_path)
            
            game_json_path = os.path.normpath(game_json_path)
            
            if not game_json_path.endswith(".json"):
                # 有些 "Directory" 可能指向目录而非直接的json文件，这里我们假设它应指向json
                # 如果存在同名的json文件，则使用它
                potential_json_path = game_json_path + ".json" 
                if os.path.exists(potential_json_path):
                    game_json_path = potential_json_path
                else:
                    # 尝试查找目录下的主json文件 (例如，与目录同名的json)
                    dir_name = os.path.basename(game_json_path)
                    potential_json_path_in_dir = os.path.join(game_json_path, f"{dir_name}.json")
                    if os.path.exists(potential_json_path_in_dir):
                         game_json_path = potential_json_path_in_dir
                    else:
                        print(f"警告: 游戏 '{game_name}' 的路径 '{item.get('Directory')}' 未指向有效的JSON文件，跳过。")
                        continue
            
            if os.path.exists(game_json_path):
                print(f"扫描游戏: '{game_name}' 从文件: {game_json_path}")
                self._scan_workshop_game_json(game_json_path, game_name)
                scanned_games_count += 1
            else:
                print(f"警告: 游戏 '{game_name}' 的JSON文件未找到: {game_json_path}，跳过。")
        
        # （可选）保留对Saves目录的扫描，以处理非工坊物品或自定义游戏
        # saves_dir = os.path.join(cfg.TTS_DATA_DIRECTORY, "Saves")
        # if os.path.exists(saves_dir):
        #     print("扫描Saves目录以查找自定义游戏...")
        #     self._scan_directory(saves_dir) # _scan_directory 需要相应调整或重写
        
        # 保存处理结果
        if scanned_games_count > 0:
            self._save_processed_mods()
        
        print(f"工坊扫描完成，共处理 {scanned_games_count} 个来自 WorkshopFileInfos.json 的游戏。")
        print(f"总共 {len(self.processed_mods)} 个游戏已记录在案。")
    
    def _scan_workshop_game_json(self, game_json_path: str, game_name: str):
        """扫描单个工坊游戏的JSON文件，查找Custom_PDF并提取规则书引用。"""
        try:
            with open(game_json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except json.JSONDecodeError:
            print(f"错误: 解析游戏JSON文件失败: {game_json_path}")
            return
        except Exception as e:
            print(f"读取游戏JSON文件时发生未知错误 {game_json_path}: {e}")
            return
        
        rulebook_refs = []
        if "ObjectStates" in data and isinstance(data["ObjectStates"], list):
            for obj_state in data["ObjectStates"]:
                if isinstance(obj_state, dict) and obj_state.get("Name") == "Custom_PDF":
                    custom_pdf_data = obj_state.get("CustomPDF")
                    if isinstance(custom_pdf_data, dict):
                        # PDF URL可能在 'PDFUrl', 'FileURL', 或 'URL' (旧格式)字段
                        pdf_url = (custom_pdf_data.get("PDFUrl") or
                                   custom_pdf_data.get("FileURL") or
                                   custom_pdf_data.get("URL"))
                        if pdf_url and isinstance(pdf_url, str) and pdf_url.lower().endswith(".pdf"):
                            rulebook_refs.append(pdf_url)
                            print(f"  在 '{game_name}' 中找到PDF: {pdf_url}")
                        # 有些PDF对象可能没有直接的URL，而是空的，或者指向本地文件（我们目前不处理本地文件）
        
        if rulebook_refs:
            self._process_rulebook_refs(game_name, rulebook_refs)
        else:
            # 如果没有找到PDF引用，但游戏本身是新的，我们可能仍想为它创建一个默认条目
            # 以便用户可以手动添加一个通用规则书
            if game_name not in self.processed_mods:
                print(f"游戏 '{game_name}' 未找到直接的PDF引用，将考虑创建默认规则书条目。")
                self.create_default_rulebook_entry(game_name) # 确保此方法会保存
    
    def _scan_directory(self, directory: str):
        """扫描指定目录中的JSON文件 (主要用于Saves目录的后备扫描)。"""
        # 此方法现在主要作为后备，或者如果需要明确扫描非工坊内容时使用。
        # 它需要与 _scan_workshop_game_json 的逻辑协调，
        # 或者专注于查找非 Custom_PDF 形式的规则书引用（例如在Notebook中）。
        print(f"执行目录扫描: {directory} (此功能可能需要审查以适应新的扫描逻辑)")
        json_files = glob.glob(os.path.join(directory, "**", "*.json"), recursive=True)
        
        for json_file in json_files:
            try:
                with open(json_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                game_name = data.get('SaveName') # Saves通常使用SaveName
                if not game_name:
                    # 对于其他JSON（可能来自旧的Mods扫描），尝试'Name'
                    game_name = data.get('Name') 
                
                if not game_name:
                    continue
                
                print(f"  扫描文件: {json_file} (游戏名: {game_name})")
                # 对于Saves目录的扫描，我们可能需要不同的逻辑来查找规则书
                # 例如，只查找 Notebook 中的引用，或者假设用户会手动关联
                # 为避免与 workshop 扫描冲突，这里的处理需要小心
                # 暂时，我们只记录游戏，并允许用户手动处理或创建默认规则书
                if game_name not in self.processed_mods:
                     self.create_default_rulebook_entry(game_name)
                
                # 旧的规则书查找逻辑（主要用于Notebook）
                # notebook_refs = self._find_rulebook_refs_in_notebook(data) 
                # if notebook_refs:
                #     self._process_rulebook_refs(game_name, notebook_refs)
                
            except (json.JSONDecodeError, UnicodeDecodeError):
                # print(f"警告: 解析JSON文件失败: {json_file}")
                continue # 静默处理这些错误，因为可能有许多非TTS相关的JSON
            except Exception as e:
                print(f"处理文件 {json_file} 时发生错误: {e}")
                continue
    
    def _find_rulebook_refs_in_notebook(self, data: Dict) -> List[str]:
        """在游戏数据的Notebook中查找规则书引用 (PDF链接)。"""
        rulebook_refs = []
        if isinstance(data, dict):
            notebook_tabs = data.get('Notebook', [])
            if isinstance(notebook_tabs, list):
                for tab in notebook_tabs:
                    if isinstance(tab, dict):
                        content = tab.get('Content', '')
                        if isinstance(content, str) and '.pdf' in content.lower():
                            # 正则表达式查找URL，需要考虑 http, https 和本地文件路径 (尽管我们主要关注URL)
                            # 这个正则表达式会匹配包含.pdf的URL
                            pdf_matches = re.findall(r'https?://[^\\s<>"\\]+?\\.pdf|file:///[^\\s<>"\\]+?\\.pdf|[^\\s<>"\\]*\\b\\w+\\.pdf\\b', content, re.IGNORECASE)
                            for match in pdf_matches:
                                # 过滤掉明显不是规则书的PDF，或进行一些基本验证
                                if 'steamusercontent' in match or 'drive.google.com' in match or match.startswith('http'):
                                    rulebook_refs.append(match)
                                    print(f"  在Notebook中找到潜在PDF: {match}")
        return rulebook_refs
    
    def _process_rulebook_refs(self, game_name: str, rulebook_refs: List[Union[str, Dict]]):
        """处理游戏中的规则书引用。rulebook_refs可以是URL字符串列表或字典列表。"""
        if game_name not in self.processed_mods:
            self.processed_mods[game_name] = {
                "_game_display_name": game_name,
                "rulebooks": {}
            }
        
        current_rulebooks = self.processed_mods[game_name].get("rulebooks", {})
        new_display_id_start = len(current_rulebooks) + 1
        
        for i, ref_item in enumerate(rulebook_refs):
            ref_url: Optional[str] = None
            original_source_name: Optional[str] = None # 用于文件名
            
            if isinstance(ref_item, str):
                ref_url = ref_item
                original_source_name = os.path.basename(pathlib.PurePosixPath(ref_url).name) # 从URL获取文件名
            elif isinstance(ref_item, dict): # 为未来扩展，如果ref是更复杂的对象
                ref_url = ref_item.get("url")
                original_source_name = ref_item.get("name") or os.path.basename(pathlib.PurePosixPath(ref_url).name if ref_url else "rulebook")
            
            if not ref_url:
                continue
            
            # 使用 ref_url 作为唯一的标识符 key
            pdf_identifier_key = ref_url
            
            # 检查此PDF是否已作为规则书存在 (基于其URL)
            existing_rulebook = next((rb for rb_key, rb in current_rulebooks.items() if rb.get("original_source") == ref_url), None)
            if existing_rulebook:
                print(f"  规则书 {ref_url} 已为游戏 '{game_name}' 处理过，跳过。")
                continue
            
            # 从引用中提取文件名，移除查询参数和片段
            try:
                parsed_url = pathlib.PurePosixPath(ref_url.split('?')[0].split('#')[0])
                filename = parsed_url.name
                if not filename or not filename.lower().endswith('.pdf'):
                    filename = original_source_name or "rulebook.pdf" # 后备文件名
            except Exception:
                filename = original_source_name or "rulebook.pdf"
            
            # 创建一个对文件名更友好的 slug
            slugified_name_part = self.slugify(os.path.splitext(filename)[0])
            # 确保文件名不会太长，并尝试保持唯一性
            timestamp_suffix = hex(abs(hash(ref_url)))[2:10] # 使用哈希的一部分增加唯一性
            max_len_slug = 30
            if len(slugified_name_part) > max_len_slug:
                slugified_name_part = slugified_name_part[:max_len_slug]
            
            normalized_filename = f"rulebook_{slugified_name_part}_{timestamp_suffix}.md"
            
            # 创建规则书缓存文件
            editable_text_path = self.rulebook_manager.create_rulebook_file(game_name, normalized_filename)
            if not editable_text_path:
                print(f"错误: 无法为游戏 '{game_name}' 创建规则书缓存文件 '{normalized_filename}'")
                continue
            
            # 添加规则书元数据
            display_id = str(new_display_id_start + i) 
            current_rulebooks[pdf_identifier_key] = {
                "original_source": ref_url, # 存储原始URL
                "normalized_filename": normalized_filename,
                "editable_text_path": str(editable_text_path), #确保是字符串
                "status": "awaiting_user_content",
                "display_id": display_id
            }
            print(f"  为 '{game_name}' 添加规则书: {normalized_filename} (ID: {display_id}) from {ref_url}")
        
        self.processed_mods[game_name]["rulebooks"] = current_rulebooks
        # 保存通常在扫描所有workshop items之后进行，或在create_default_rulebook_entry中单独进行
    
    def create_default_rulebook_entry(self, game_name: str):
        """为游戏创建默认的规则书条目"""
        if game_name not in self.processed_mods:
            self.processed_mods[game_name] = {
                "_game_display_name": game_name,
                "rulebooks": {}
            }
        
        # 默认规则书标识符
        default_key = f"default_for_{self.slugify(game_name)}" # slugify game_name for key
        
        # 如果默认规则书已经存在，跳过
        if default_key in self.processed_mods[game_name].get("rulebooks", {}):
            return
        
        # 创建默认规则书文件名
        normalized_filename = f"rulebook_default_for_{self.slugify(game_name)}.md"
        
        # 创建规则书缓存文件
        editable_text_path = self.rulebook_manager.create_rulebook_file(game_name, normalized_filename)
        
        # 添加规则书元数据
        self.processed_mods[game_name]["rulebooks"][default_key] = {
            "original_source": default_key,
            "normalized_filename": normalized_filename,
            "editable_text_path": str(editable_text_path), #确保是字符串
            "status": "awaiting_user_content",
            "display_id": str(len(self.processed_mods[game_name]["rulebooks"]) + 1)
        }
        
        # 保存更新
        self._save_processed_mods()
    
    def get_game_rulebook_info(self, game_name: str) -> List[Dict]:
        """获取游戏的规则书信息列表"""
        rulebooks_data = [] # 更名为 rulebooks_data 以避免与局部变量 rulebooks 混淆
        
        game_data = self.processed_mods.get(game_name)
        if game_data:
            for pdf_key, rulebook_info in game_data.get("rulebooks", {}).items():
                rulebooks_data.append({
                    "id": rulebook_info.get("display_id", ""),
                    "name": rulebook_info.get("normalized_filename", pdf_key), # Fallback to key if name is missing
                    "status": rulebook_info.get("status", ""),
                    "path": str(rulebook_info.get("editable_text_path", "")), # Ensure path is string
                    "original_source": rulebook_info.get("original_source", pdf_key)
                })
        
        # 按 display_id 排序 (如果存在且为数字)
        try:
            rulebooks_data.sort(key=lambda x: int(x.get("id", 0)))
        except ValueError:
            # 如果id不是纯数字，则按原样返回或按其他标准排序
            pass
        
        return rulebooks_data
    
    def has_game(self, game_name: str) -> bool:
        """检查是否存在指定游戏的元数据"""
        return game_name in self.processed_mods
    
    def check_auto_load_rulebook(self, game_name: str) -> Optional[Dict]:
        """检查是否有可自动加载的规则书"""
        if game_name in self.processed_mods:
            rulebooks = self.processed_mods[game_name].get("rulebooks", {})
            
            # 如果只有一个规则书，返回它的信息
            if len(rulebooks) == 1:
                pdf_identifier_key = next(iter(rulebooks))
                return {
                    "pdf_identifier_key": pdf_identifier_key,
                    **rulebooks[pdf_identifier_key]
                }
        
        return None
    
    def update_rulebook_status(self, game_name: str, pdf_identifier_key: str, status: str):
        """更新规则书状态"""
        if (game_name in self.processed_mods and 
            pdf_identifier_key in self.processed_mods[game_name].get("rulebooks", {})):
            self.processed_mods[game_name]["rulebooks"][pdf_identifier_key]["status"] = status
            self._save_processed_mods()
    
    def resolve_rulebook_path(self, game_name: str, identifier: str) -> Optional[str]:
        """根据编号或部分文件名解析规则书路径"""
        if game_name not in self.processed_mods:
            return None
        
        rulebooks = self.processed_mods[game_name].get("rulebooks", {})
        
        # 尝试按编号查找
        for pdf_key, info in rulebooks.items():
            if info.get("display_id") == identifier:
                return info.get("editable_text_path")
        
        # 尝试按部分文件名查找
        for pdf_key, info in rulebooks.items():
            filename = info.get("normalized_filename", "")
            if identifier.lower() in filename.lower():
                return info.get("editable_text_path")
        
        return None
    
    def get_identifier_key_by_path(self, game_name: str, path: str) -> Optional[str]:
        """根据文件路径获取pdf_identifier_key"""
        if game_name not in self.processed_mods:
            return None
        
        rulebooks = self.processed_mods[game_name].get("rulebooks", {})
        
        for pdf_key, info in rulebooks.items():
            if info.get("editable_text_path") == path:
                return pdf_key
        
        return None 