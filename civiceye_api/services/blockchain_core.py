import hashlib
import json
import time
import os
from typing import List
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")


supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)


class Block:
    def __init__(self, index, timestamp, data, previous_hash, hash=None):
        self.index = index
        self.timestamp = timestamp
        self.data = data
        self.previous_hash = previous_hash
        self.hash = hash or self.compute_hash()

    def compute_hash(self):
        block_data = {
            "index": self.index,
            "timestamp": self.timestamp,
            "data": self.data,
            "previous_hash": self.previous_hash
        }
        block_string = json.dumps(block_data, sort_keys=True)
        return hashlib.sha256(block_string.encode()).hexdigest()


class Blockchain:
    def __init__(self):
        self.chain: List[Block] = []
        self._load_chain()

    def _load_chain(self):
        try:
            response = supabase.table("blockchain").select("chain_data").order("id").execute()
            chain_data = [row["chain_data"] for row in response.data]

            if chain_data:
                for block_data in chain_data:
                    if isinstance(block_data, dict):
                        self.chain.append(Block(**block_data))
                    else:
                        print(f"Skipping invalid block data: {block_data}")
                print(f"Blockchain loaded from Supabase with {len(self.chain)} blocks.")
            
            if not self.chain:
                print("No valid blocks loaded, creating genesis block")
                self._create_genesis_block()
                self._save_block(self.chain[0], user_id="00000000-0000-0000-0000-000000000000")
        except Exception as e:
            print("Error loading chain from Supabase:", str(e))
            if not self.chain:
                self._create_genesis_block()
                self._save_block(self.chain[0], user_id="00000000-0000-0000-0000-000000000000")

    def _save_block(self, block: Block, user_id: str):
        try:
            import datetime
            iso_timestamp = datetime.datetime.fromtimestamp(block.timestamp).isoformat()

            if user_id == "anonymous" or user_id == "system":
                user_id = "00000000-0000-0000-0000-000000000000"
            
            supabase.table("blockchain").insert({
                "chain_data": block.__dict__,
                "created_at": iso_timestamp,
                "user_id": user_id
            }).execute()
            print("Block saved to Supabase.")
        except Exception as e:
            print("Error saving block to Supabase:", str(e))

    def _create_genesis_block(self):
        genesis = Block(0, time.time(), "Genesis Block", "0")
        self.chain.append(genesis)

    def latest_block(self) -> Block:
        if not self.chain:
            print("Warning: Chain is empty, creating genesis block")
            self._create_genesis_block()
            self._save_block(self.chain[0], user_id="00000000-0000-0000-0000-000000000000")
        return self.chain[-1]

    def add_block(self, data: dict):
        prev_block = self.latest_block()
        new_block = Block(
            index=prev_block.index + 1,
            timestamp=time.time(),
            data=data,
            previous_hash=prev_block.hash
        )
        self.chain.append(new_block)
        
        user_id = data.get("user_id", "00000000-0000-0000-0000-000000000000")
        if user_id == "anonymous" or not user_id:
            user_id = "00000000-0000-0000-0000-000000000000"
        
        self._save_block(new_block, user_id=user_id)
        return new_block

    def is_chain_valid(self) -> bool:
        for i in range(1, len(self.chain)):
            curr = self.chain[i]
            prev = self.chain[i - 1]
            if curr.hash != curr.compute_hash():
                return False
            if curr.previous_hash != prev.hash:
                return False
        return True

    def to_dict(self):
        return [block.__dict__ for block in self.chain]
