extends Node

# Card-related events
signal card_drag_started(card_ui: CardUI)
signal card_drag_ended(card_ui: CardUI)
signal card_aim_started(card_ui: CardUI)
signal card_aim_ended(card_ui: CardUI)
signal card_played(card: Card)

# Player-related events
signal player_hand_drawn
signal player_hand_discarded
signal player_turn_ended
signal player_hit
signal player_died

# Enemy-related events
signal enemy_action_completed(enemy: Enemy)
signal enemy_turn_ended
signal enemy_died(enemy: Enemy)

# Battle-related events
signal battle_over_screen_requested(text: String, type: BattleOverPanel.Type)
signal battle_won
signal status_tooltip_requested(statuses: Array[Status])
## 战斗/地图：悬停在单个状态图标上显示说明；open_to_right 为 true 时框在图标右侧（玩家），false 时在左侧（敌人）
signal status_tooltip_hover_show(status: Status, near_to: Control, open_to_right: bool)
signal status_tooltip_hover_hide

# Map-related events
signal map_exited(room: Room)

# Shop-related events
signal shop_entered(shop: Shop)
signal shop_relic_bought(relic: Relic, gold_cost: int)
signal shop_card_bought(card: Card, gold_cost: int, from_control: Control)
signal shop_exited

# Campfire-related events
signal campfire_exited

# Battle Reward-related events
signal battle_reward_exited

# Treasure Room-related events
signal treasure_room_exited(found_relic: Relic)

# Relic-related事件：悬停显示说明；near_to 用于把提示框摆在遗物旁（RelicUI 等 Control）
signal relic_tooltip_hover_show(relic: Relic, near_to: Control)
signal relic_tooltip_hover_hide

# Random Event room-related events
signal event_room_exited
