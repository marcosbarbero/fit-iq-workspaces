#!/usr/bin/env python3
"""
WebSocket Test with Goal Context - Verify Goal-Aware AI
"""

import asyncio
import json
import os
import sys

import requests
import websockets

BASE_URL = "fit-iq-backend.fly.dev"
API_KEY = os.environ.get("API_KEY")


def log(message):
    print(f"[TEST] {message}")


def authenticate():
    log("Authenticating...")
    response = requests.post(
        f"https://{BASE_URL}/api/v1/auth/login",
        headers={"Content-Type": "application/json", "X-API-Key": API_KEY},
        json={"email": "1411@lume.com", "password": "123Senha"},
    )
    if response.status_code != 200:
        log(f"❌ Auth failed with status {response.status_code}")
        log(f"Response: {response.text[:200]}")
        raise Exception(f"Authentication failed: {response.status_code}")
    token = response.json()["data"]["access_token"]
    log(f"✅ Token obtained")
    return token


def create_test_goal(token):
    log("Creating concrete test goal...")

    # Create a realistic, concrete goal for testing
    goal_data = {
        "goal_type": "weight",
        "title": "Lose 15 pounds for summer vacation",
        "description": "I want to lose weight before my beach trip in July. I've been struggling with portion control and need to get back to regular exercise.",
        "target_value": 165.0,
        "target_unit": "lbs",
        "current_value": 180.0,
        "start_date": "2025-01-20",
        "target_date": "2025-07-01",
    }

    response = requests.post(
        f"https://{BASE_URL}/api/v1/goals",
        headers={
            "Content-Type": "application/json",
            "X-API-Key": API_KEY,
            "Authorization": f"Bearer {token}",
        },
        json=goal_data,
    )

    if response.status_code != 201:
        log(f"❌ Failed to create goal: {response.status_code}")
        log(f"Response: {response.text}")
        raise Exception(f"Failed to create test goal")

    response_json = response.json()
    log(f"Response JSON: {response_json}")

    # Handle both possible response structures
    if "data" in response_json and "goal" in response_json["data"]:
        goal = response_json["data"]["goal"]
    elif "data" in response_json:
        goal = response_json["data"]
    else:
        goal = response_json
    log(f"✅ Created test goal: '{goal['title']}'")
    log(f"   Type: {goal['goal_type']}")
    log(f"   Current: {goal['current_value']} {goal['target_unit']}")
    log(f"   Target: {goal['target_value']} {goal['target_unit']}")
    log(
        f"   To lose: {goal['current_value'] - goal['target_value']} {goal['target_unit']}"
    )
    return goal


def delete_test_goal(token, goal_id):
    log(f"Deleting test goal {goal_id}...")
    response = requests.delete(
        f"https://{BASE_URL}/api/v1/goals/{goal_id}",
        headers={
            "X-API-Key": API_KEY,
            "Authorization": f"Bearer {token}",
        },
    )
    if response.status_code == 204:
        log(f"✅ Test goal deleted successfully")
    else:
        log(f"⚠️  Failed to delete test goal: {response.status_code}")


def cleanup_all_consultations(token):
    log(f"Cleaning up all active consultations...")
    response = requests.get(
        f"https://{BASE_URL}/api/v1/consultations?status=active",
        headers={
            "X-API-Key": API_KEY,
            "Authorization": f"Bearer {token}",
        },
    )

    if response.status_code == 200:
        consultations = response.json()["data"]["consultations"]
        for consultation in consultations:
            consultation_id = consultation["id"]
            delete_response = requests.delete(
                f"https://{BASE_URL}/api/v1/consultations/{consultation_id}",
                headers={
                    "X-API-Key": API_KEY,
                    "Authorization": f"Bearer {token}",
                },
            )
            if delete_response.status_code == 204:
                log(f"   ✅ Deleted consultation {consultation_id}")
            else:
                log(
                    f"   ⚠️  Failed to delete consultation {consultation_id}: {delete_response.status_code}"
                )
        log(f"✅ Cleanup complete ({len(consultations)} consultations deleted)")
    else:
        log(f"⚠️  Failed to fetch consultations: {response.status_code}")


def create_consultation_with_goal(token, goal_id):
    log(f"Creating consultation with goal context...")
    response = requests.post(
        f"https://{BASE_URL}/api/v1/consultations",
        headers={
            "Content-Type": "application/json",
            "X-API-Key": API_KEY,
            "Authorization": f"Bearer {token}",
        },
        json={
            "persona": "wellness_specialist",
            "context_type": "goal",
            "context_id": goal_id,
        },
    )
    if response.status_code != 201:
        log(f"❌ Failed to create consultation: {response.status_code}")
        log(f"Response: {response.text}")
        raise Exception(f"Failed to create consultation: {response.status_code}")

    response_json = response.json()
    consultation = response_json["data"]["consultation"]
    log(f"✅ Consultation created: {consultation['id']}")
    log(f"   Persona: {consultation['persona']}")
    log(f"   Has context: {consultation.get('context_type', 'none')}")
    return consultation["id"]


def cleanup_consultation(token, consultation_id):
    log(f"Cleaning up consultation {consultation_id}...")
    response = requests.delete(
        f"https://{BASE_URL}/api/v1/consultations/{consultation_id}",
        headers={
            "X-API-Key": API_KEY,
            "Authorization": f"Bearer {token}",
        },
    )
    if response.status_code == 204:
        log(f"✅ Consultation deleted successfully")
    else:
        log(f"⚠️  Failed to delete consultation: {response.status_code}")


async def test_goal_aware_ai(token, consultation_id, goal):
    goal_title = goal["title"]
    ws_url = f"wss://{BASE_URL}/api/v1/consultations/{consultation_id}/ws"
    log(f"Connecting to WebSocket...")

    headers = {"Authorization": f"Bearer {token}", "X-API-Key": API_KEY}

    async with websockets.connect(ws_url, additional_headers=headers) as websocket:
        log("✅ Connected!")

        # Receive connected message
        msg = await asyncio.wait_for(websocket.recv(), timeout=5.0)
        data = json.loads(msg)
        log(f"✅ Connected: {data['type']}")

        # Ask AI about the goal WITHOUT mentioning it
        log("\n" + "=" * 60)
        log("TEST: Asking AI for help (WITHOUT mentioning the goal)")
        log("Expected: AI should know about the goal and reference it")
        log("=" * 60)

        await websocket.send(
            json.dumps(
                {
                    "type": "message",
                    "content": "Hi! Can you help me with what I'm trying to achieve?",
                }
            )
        )

        log("\n📡 AI Response:")
        log("-" * 60)

        full_response = ""
        stream_complete = False

        try:
            while not stream_complete:
                msg = await asyncio.wait_for(websocket.recv(), timeout=20.0)

                for line in msg.strip().split("\n"):
                    if not line.strip():
                        continue
                    data = json.loads(line)
                    msg_type = data.get("type")

                    if msg_type == "message_received":
                        pass
                    elif msg_type == "stream_chunk":
                        content = data.get("content", "")
                        full_response += content
                        print(content, end="", flush=True)
                    elif msg_type == "stream_complete":
                        print()
                        log("-" * 60)
                        stream_complete = True
                    elif msg_type == "error":
                        log(f"❌ Error: {data.get('error')}")
                        return False

        except asyncio.TimeoutError:
            log("⚠️  Timeout waiting for response")
            if full_response:
                log("But we got partial response, analyzing...")
            else:
                return False

        # Analyze response
        log("\n" + "=" * 60)
        log("ANALYSIS: Does AI know about the goal?")
        log("=" * 60)

        response_lower = full_response.lower()
        goal_title_lower = goal_title.lower()

        # First check if AI mentions the goal explicitly (GOOD)
        mentions_goal_specifically = False

        # Check for exact goal title match
        if goal_title_lower in response_lower:
            log(f"✅ AI explicitly mentioned the goal: '{goal_title}'")
            mentions_goal_specifically = True

        # Check for goal title keywords
        goal_keywords = [word for word in goal_title_lower.split() if len(word) > 3]
        for keyword in goal_keywords:
            if keyword in response_lower:
                log(f"✅ AI mentioned goal keyword: '{keyword}'")
                mentions_goal_specifically = True

        # Check for target value or unit
        target_val = str(goal.get("target_value", "")).lower()
        target_unit = str(goal.get("target_unit", "")).lower()
        if target_val in response_lower or target_unit in response_lower:
            log(f"✅ AI mentioned target: {target_val} {target_unit}")
            mentions_goal_specifically = True

        # If AI mentioned the goal, SUCCESS - even if asking follow-up questions
        if mentions_goal_specifically:
            log("\n🎉 SUCCESS! AI is GOAL-AWARE!")
            log("The AI acknowledged the specific goal and is ready to help.")
            return True

        # Only check for "asking what goal is" patterns if goal was NOT mentioned
        asking_patterns = [
            "what goal",
            "which goal",
            "what are you trying",
            "what you're trying",
            "what specific goal",
            "share more details about what you're trying",
            "tell me about your goal",
            "what are you working on",
            "what would you like to achieve",
        ]

        is_asking_for_goal = False
        for pattern in asking_patterns:
            if pattern in response_lower:
                log(f"❌ AI is asking about the goal: '{pattern}'")
                is_asking_for_goal = True
                break

        if is_asking_for_goal:
            log("\n❌ FAILURE! AI is NOT goal-aware!")
            log("The AI is asking what the goal is instead of knowing it.")
            log(f"\nExpected: AI should reference '{goal_title}'")
            log(f"Actual: AI asked for more information about the goal")
            return False

        # Unclear case
        log("\n⚠️ UNCLEAR: AI response doesn't clearly reference the specific goal")
        log(f"Goal title: '{goal_title}'")
        log(f"AI response: '{full_response[:200]}...'")
        log("\nThis suggests the goal context may not be passed correctly.")
        return False


async def main():
    log("=" * 60)
    log("Goal-Aware AI Test - WebSocket Consultation")
    log("=" * 60)

    try:
        # Step 1: Authenticate
        token = authenticate()

        # Step 2: Create a concrete test goal
        goal = create_test_goal(token)
        goal_id = goal["id"]
        goal_title = goal["title"]

        # Step 3: Cleanup existing consultations first
        cleanup_all_consultations(token)

        # Step 4: Create consultation WITH goal context
        consultation_id = create_consultation_with_goal(token, goal_id)

        # Step 5: Test AI is aware of the goal
        success = await test_goal_aware_ai(token, consultation_id, goal)

        log("\n" + "=" * 60)
        if success:
            log("✅ TEST PASSED! Goal context feature working!")
        else:
            log("❌ TEST FAILED")
        log("=" * 60)

        # Step 6: Cleanup - delete the test consultation
        cleanup_consultation(token, consultation_id)

        # Step 7: Cleanup - delete the test goal
        delete_test_goal(token, goal_id)

        return 0 if success else 1

    except Exception as e:
        log(f"❌ Error: {e}")
        import traceback

        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
