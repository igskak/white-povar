#!/usr/bin/env python3
"""
Manual recipe processing script
Run this from the backend directory to process files
"""

import asyncio
import sys
import os
from pathlib import Path

async def process_all_files():
    """Process all files in the inbox directory"""
    try:
        from app.ingestion.processor import recipe_processor
        
        inbox_path = Path("../data/ingestion/inbox")
        
        if not inbox_path.exists():
            print("❌ Inbox directory not found: ../data/ingestion/inbox")
            return False
        
        # Get all supported files
        supported_extensions = {'.txt', '.pdf', '.docx', '.doc'}
        files_to_process = []
        
        for file_path in inbox_path.iterdir():
            if file_path.is_file() and file_path.suffix.lower() in supported_extensions:
                files_to_process.append(file_path)
        
        if not files_to_process:
            print("📭 No files to process in inbox directory")
            return True
        
        print(f"🔄 Found {len(files_to_process)} files to process:")
        for file_path in files_to_process:
            print(f"   - {file_path.name}")
        
        print("\n" + "="*50)
        
        # Process each file
        results = []
        for i, file_path in enumerate(files_to_process, 1):
            print(f"\n📄 Processing file {i}/{len(files_to_process)}: {file_path.name}")
            print("-" * 40)
            
            try:
                result = await recipe_processor.process_file(str(file_path))
                
                if result.success:
                    print("✅ Processing successful!")
                    print(f"   Job ID: {result.job_id}")
                    
                    if result.recipe_id:
                        print(f"   Recipe ID: {result.recipe_id}")
                    
                    if result.is_duplicate:
                        print("   Status: Duplicate detected")
                        if result.duplicate_of_recipe_id:
                            print(f"   Duplicate of: {result.duplicate_of_recipe_id}")
                    elif result.needs_review:
                        print("   Status: Needs manual review")
                        print(f"   Confidence: {result.confidence_score:.2f}")
                    else:
                        print("   Status: Recipe created successfully")
                        print(f"   Confidence: {result.confidence_score:.2f}")
                    
                    results.append(True)
                else:
                    print(f"❌ Processing failed: {result.error_message}")
                    results.append(False)
                
            except Exception as e:
                print(f"❌ Error processing {file_path.name}: {str(e)}")
                results.append(False)
        
        # Summary
        print("\n" + "="*50)
        print("📊 PROCESSING SUMMARY")
        print("="*50)
        
        successful = sum(results)
        total = len(results)
        
        print(f"Total files: {total}")
        print(f"Successful: {successful}")
        print(f"Failed: {total - successful}")
        print(f"Success rate: {(successful/total)*100:.1f}%")
        
        if successful == total:
            print("\n🎉 All files processed successfully!")
        elif successful > 0:
            print(f"\n⚠️  {total - successful} files failed processing")
        else:
            print("\n❌ All files failed processing")
        
        return successful > 0
        
    except Exception as e:
        print(f"❌ Script failed: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main function"""
    print("🍳 Recipe Processing Tool")
    print("=" * 40)
    print("Processing all files in inbox directory...")
    
    success = asyncio.run(process_all_files())
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
