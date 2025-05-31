import unittest
import os
import json
import shutil
import tempfile
from unittest.mock import patch, MagicMock

# 将项目根目录添加到sys.path，以便导入模块
import sys
# 获取当前脚本的目录 (TTSAssistantServer/tests)
current_dir = os.path.dirname(os.path.abspath(__file__))
# 获取项目根目录 (TTSAssistantServer)
project_root = os.path.dirname(current_dir)
# 将项目根目录添加到 sys.path
sys.path.insert(0, project_root)

from services.workshop_manager import WorkshopManager
from services.rulebook_manager import RulebookManager # RulebookManager 会被 WorkshopManager内部实例化
import config as cfg

class TestWorkshopManager(unittest.TestCase):

    def setUp(self):
        # 1. 创建临时目录结构
        self.test_dir = tempfile.mkdtemp(prefix="tts_companion_test_")
        
        self.mock_tts_data_dir = os.path.join(self.test_dir, "TTS_User_Data")
        self.mock_mods_dir = os.path.join(self.mock_tts_data_dir, "Mods")
        self.mock_workshop_dir = os.path.join(self.mock_mods_dir, "Workshop")
        
        self.mock_cache_dir = os.path.join(self.test_dir, "Cache_Data")
        self.mock_editable_texts_dir = os.path.join(self.mock_cache_dir, "editable_rulebook_texts")
        self.mock_vector_stores_dir = os.path.join(self.mock_cache_dir, "vector_stores")
        self.mock_processed_mods_file = os.path.join(self.mock_cache_dir, "processed_mods.json")

        os.makedirs(self.mock_tts_data_dir, exist_ok=True)
        os.makedirs(self.mock_mods_dir, exist_ok=True)
        os.makedirs(self.mock_workshop_dir, exist_ok=True)
        os.makedirs(self.mock_cache_dir, exist_ok=True)
        os.makedirs(self.mock_editable_texts_dir, exist_ok=True)
        os.makedirs(self.mock_vector_stores_dir, exist_ok=True)

        # 2. 准备模拟的 WorkshopFileInfos.json
        self.game1_id = "12345"
        self.game1_name = "Awesome Game 1"
        self.game1_pdf_url = "http://example.com/rules1.pdf"
        self.game1_json_filename = f"{self.game1_id}.json"
        self.game1_json_path = os.path.join(self.mock_workshop_dir, self.game1_json_filename)

        self.game2_id = "67890"
        self.game2_name = "Super Game 2"
        # Game 2 has two PDFs
        self.game2_pdf_url1 = "http://example.com/super_rules_main.pdf"
        self.game2_pdf_url2 = "http://example.com/super_rules_expansion.pdf"
        self.game2_json_filename = f"{self.game2_id}.json"
        self.game2_json_path = os.path.join(self.mock_workshop_dir, self.game2_json_filename)
        
        self.game3_name = "No PDF Game 3" # Game with no PDF
        self.game3_id = "11111"
        self.game3_json_filename = f"{self.game3_id}.json"
        self.game3_json_path = os.path.join(self.mock_workshop_dir, self.game3_json_filename)


        workshop_infos_content = [
            {
                "Directory": self.game1_json_path, # Critical: Ensure this path is correct for the test env
                "Name": self.game1_name,
                "UpdateTime": 1700000000
            },
            {
                "Directory": self.game2_json_path,
                "Name": self.game2_name,
                "UpdateTime": 1700000001
            },
            {
                "Directory": self.game3_json_path,
                "Name": self.game3_name,
                "UpdateTime": 1700000002
            }
        ]
        self.workshop_file_infos_path = os.path.join(self.mock_workshop_dir, "WorkshopFileInfos.json")
        with open(self.workshop_file_infos_path, 'w', encoding='utf-8') as f:
            json.dump(workshop_infos_content, f)

        # 3. 准备模拟的游戏JSON文件
        game1_content = {
            "Name": self.game1_name,
            "ObjectStates": [
                {
                    "Name": "Custom_PDF",
                    "CustomPDF": {
                        "PDFUrl": self.game1_pdf_url
                    }
                }
            ]
        }
        with open(self.game1_json_path, 'w', encoding='utf-8') as f:
            json.dump(game1_content, f)

        game2_content = {
            "Name": self.game2_name,
            "ObjectStates": [
                {
                    "Name": "Custom_Model", # Irrelevant object
                    "CustomMesh": {}
                },
                {
                    "Name": "Custom_PDF",
                    "CustomPDF": {
                        "PDFUrl": self.game2_pdf_url1 
                    }
                },
                {
                    "Name": "Another_Object"
                },
                {
                    "Name": "Custom_PDF",
                    "CustomPDF": {
                        "FileURL": self.game2_pdf_url2 # Using FileURL here
                    }
                }
            ]
        }
        with open(self.game2_json_path, 'w', encoding='utf-8') as f:
            json.dump(game2_content, f)
            
        game3_content = { # No PDF objects
            "Name": self.game3_name,
            "ObjectStates": [
                {"Name": "Deck", "GUID": "game3deck"}
            ]
        }
        with open(self.game3_json_path, 'w', encoding='utf-8') as f:
            json.dump(game3_content, f)

        # 4. Patch config values
        self.patches = [
            patch.object(cfg, 'TTS_DATA_DIRECTORY', self.mock_tts_data_dir),
            patch.object(cfg, 'PROCESSED_MODS_FILE', self.mock_processed_mods_file),
            patch.object(cfg, 'EDITABLE_RULEBOOK_TEXT_CACHE_DIRECTORY', self.mock_editable_texts_dir),
            patch.object(cfg, 'VECTOR_STORE_DIRECTORY', self.mock_vector_stores_dir)
        ]
        for p in self.patches:
            p.start()
            self.addCleanup(p.stop) # Ensures patches are stopped even if test fails

    def tearDown(self):
        # 清理临时目录
        shutil.rmtree(self.test_dir)

    def test_scan_all_tts_data_extracts_pdfs(self):
        # 实例化 WorkshopManager (它会内部创建 RulebookManager)
        workshop_manager = WorkshopManager()
        
        # 执行扫描
        workshop_manager.scan_all_tts_data()

        # 断言 processed_mods.json 文件已创建
        self.assertTrue(os.path.exists(self.mock_processed_mods_file))

        # 加载并检查 processed_mods.json 的内容
        with open(self.mock_processed_mods_file, 'r', encoding='utf-8') as f:
            processed_data = json.load(f)

        # 检查游戏1
        self.assertIn(self.game1_name, processed_data)
        game1_rulebooks = processed_data[self.game1_name].get("rulebooks", {})
        self.assertEqual(len(game1_rulebooks), 1)
        
        game1_pdf_key = self.game1_pdf_url # key is the URL
        self.assertIn(game1_pdf_key, game1_rulebooks)
        self.assertEqual(game1_rulebooks[game1_pdf_key]["original_source"], self.game1_pdf_url)
        self.assertTrue(game1_rulebooks[game1_pdf_key]["normalized_filename"].startswith("rulebook_rules1_"))
        self.assertTrue(game1_rulebooks[game1_pdf_key]["normalized_filename"].endswith(".md"))
        
        expected_md_path_game1 = os.path.join(
            self.mock_editable_texts_dir, 
            workshop_manager.slugify(self.game1_name), # game_name slug
            game1_rulebooks[game1_pdf_key]["normalized_filename"]
        )
        self.assertEqual(os.path.normpath(game1_rulebooks[game1_pdf_key]["editable_text_path"]), 
                         os.path.normpath(expected_md_path_game1))
        self.assertTrue(os.path.exists(expected_md_path_game1))

        # 检查游戏2
        self.assertIn(self.game2_name, processed_data)
        game2_rulebooks = processed_data[self.game2_name].get("rulebooks", {})
        self.assertEqual(len(game2_rulebooks), 2) # Expecting two PDFs

        game2_pdf1_key = self.game2_pdf_url1
        game2_pdf2_key = self.game2_pdf_url2
        self.assertIn(game2_pdf1_key, game2_rulebooks)
        self.assertIn(game2_pdf2_key, game2_rulebooks)

        self.assertEqual(game2_rulebooks[game2_pdf1_key]["original_source"], self.game2_pdf_url1)
        self.assertTrue(game2_rulebooks[game2_pdf1_key]["normalized_filename"].startswith("rulebook_super_rules_main_"))
        
        self.assertEqual(game2_rulebooks[game2_pdf2_key]["original_source"], self.game2_pdf_url2)
        self.assertTrue(game2_rulebooks[game2_pdf2_key]["normalized_filename"].startswith("rulebook_super_rules_expansion_"))

        expected_md_path_game2_pdf1 = os.path.join(
            self.mock_editable_texts_dir,
            workshop_manager.slugify(self.game2_name),
            game2_rulebooks[game2_pdf1_key]["normalized_filename"]
        )
        self.assertTrue(os.path.exists(expected_md_path_game2_pdf1))
        
        expected_md_path_game2_pdf2 = os.path.join(
            self.mock_editable_texts_dir,
            workshop_manager.slugify(self.game2_name),
            game2_rulebooks[game2_pdf2_key]["normalized_filename"]
        )
        self.assertTrue(os.path.exists(expected_md_path_game2_pdf2))
        
        # 检查游戏3 (No PDF)
        self.assertIn(self.game3_name, processed_data)
        game3_rulebooks = processed_data[self.game3_name].get("rulebooks", {})
        self.assertEqual(len(game3_rulebooks), 1) # Should have a default entry
        
        default_key_game3 = f"default_for_{workshop_manager.slugify(self.game3_name)}"
        self.assertIn(default_key_game3, game3_rulebooks)
        self.assertEqual(game3_rulebooks[default_key_game3]["original_source"], default_key_game3)
        self.assertEqual(game3_rulebooks[default_key_game3]["normalized_filename"], 
                         f"rulebook_default_for_{workshop_manager.slugify(self.game3_name)}.md")
        
        expected_md_path_game3 = os.path.join(
             self.mock_editable_texts_dir,
             workshop_manager.slugify(self.game3_name),
             game3_rulebooks[default_key_game3]["normalized_filename"]
        )
        self.assertTrue(os.path.exists(expected_md_path_game3))


    def test_scan_all_tts_data_no_workshop_file(self):
        # 删除 WorkshopFileInfos.json 以模拟文件不存在的场景
        if os.path.exists(self.workshop_file_infos_path):
            os.remove(self.workshop_file_infos_path)

        workshop_manager = WorkshopManager()
        workshop_manager.scan_all_tts_data()

        # processed_mods.json 不应该被创建或修改 (因为初始扫描依赖 WorkshopFileInfos.json)
        self.assertFalse(os.path.exists(self.mock_processed_mods_file),
                         "processed_mods.json should not be created if WorkshopFileInfos.json is missing.")

    def test_idempotency_and_no_duplicates(self):
        # 第一次扫描
        manager = WorkshopManager()
        manager.scan_all_tts_data()
        
        with open(self.mock_processed_mods_file, 'r', encoding='utf-8') as f:
            data_first_scan = json.load(f)
        
        # 确保 game1 只有一个 rulebook
        self.assertEqual(len(data_first_scan[self.game1_name]["rulebooks"]), 1)
        first_scan_game1_rulebook_entry = list(data_first_scan[self.game1_name]["rulebooks"].values())[0]

        # 第二次扫描
        # WorkshopManager会重新加载processed_mods.json，所以我们使用同一个实例或者新实例都可以
        manager_second_scan = WorkshopManager() # 新实例会从文件加载状态
        manager_second_scan.scan_all_tts_data()

        with open(self.mock_processed_mods_file, 'r', encoding='utf-8') as f:
            data_second_scan = json.load(f)

        # 游戏1的规则书数量不应该改变
        self.assertEqual(len(data_second_scan[self.game1_name]["rulebooks"]), 1)
        second_scan_game1_rulebook_entry = list(data_second_scan[self.game1_name]["rulebooks"].values())[0]
        
        # 规则书的条目信息（如文件名、路径）应该保持一致
        self.assertEqual(first_scan_game1_rulebook_entry["normalized_filename"], 
                         second_scan_game1_rulebook_entry["normalized_filename"])
        self.assertEqual(first_scan_game1_rulebook_entry["editable_text_path"],
                         second_scan_game1_rulebook_entry["editable_text_path"])
        
        # 游戏2的规则书数量也不应该改变
        self.assertEqual(len(data_second_scan[self.game2_name]["rulebooks"]), 2)


if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'], exit=False) 