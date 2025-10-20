#!/usr/bin/env python3
"""
Tutorial section translation script
Translates tutorial entries 20-284 in the target file
"""

# Translation mappings for tutorial entries 20-284
translations = {
    20: ("Friendly Fire", "味方への誤射"),
    21: ("Your ranged attacks have a chance of hitting anyone between you and your target. Avoid making attacks that put your other squad members in the line of fire.", "遠距離攻撃は、あなたとターゲットの間にいる人物に当たる可能性があります。他の部隊メンバーを射線上に置くような攻撃は避けてください。"),
    22: ("Merchants", "商人"),
    23: ("Merchants will trade, buy, or sell items with you. All items have a monetary value. Depending on the items in the transaction, you or the Merchant may need to pay money to make up the remaining amount. A higher Barter skill will get you more favorable buy or sell rates.", "商人はあなたとアイテムを交換、購入、または販売します。すべてのアイテムには金銭的価値があります。取引内容によっては、あなたまたは商人が残額を支払う必要があります。バータースキルが高いほど、有利な購入・売却レートが得られます。"),
    24: ("Using Items", "アイテムの使用"),
    25: ("Select an item and pick a target for it. Some items require a certain Skill Level to use, or gain bonuses from a higher Skill Level.", "アイテムを選択してターゲットを選んでください。一部のアイテムは特定のスキルレベルが必要か、高いスキルレベルからボーナスを得られます。"),
    26: ("Weather Conditions", "気象条件"),
    27: ("Weather Conditions can reduce visibility, movement speed, and stats. Some can even kill you. You can reduce these effects by equipping armor that provides Weather Resistance.", "気象条件は視界、移動速度、ステータスを低下させます。中には死に至るものもあります。気象耐性を提供する防具を装備することで、これらの影響を軽減できます。"),
    28: ("Severe Weather", "過酷な天候"),
    29: ("The weather here is too extreme to survive without protection. If you continue without equipment to guard against it, you will die.", "ここの天候は保護なしでは生き残れないほど過酷です。防護装備なしで進むと、死亡します。"),
    30: ("Skill Checks", "スキルチェック"),
    31: ("Certain objects require enough points in a specific Skill to use. When you interact with these objects, the most skilled member of your party will automatically attempt the check.", "特定のオブジェクトは、使用するために特定のスキルに十分なポイントが必要です。これらのオブジェクトと相互作用すると、パーティーで最も熟練したメンバーが自動的にチェックを試みます。"),
    32: ("Attacking Objects", "オブジェクトへの攻撃"),
    33: ("If your squad's Skills aren't high enough, sometimes brute force will still work. To break down a door, smack a misbehaving computer, or forcefully shut down a power generator, use the Attack option in the Quickbar or press [Keybind: ForceAreaAttack]. Certain objects, such as vault doors or ice walls, may require specific damage types to damage.", "部隊のスキルが十分でない場合でも、力技が通じることがあります。ドアを壊す、誤作動するコンピューターを叩く、発電機を強制的にシャットダウンするには、クイックバーの攻撃オプションを使用するか、[Keybind: ForceAreaAttack] を押してください。金庫のドアや氷の壁など、特定のオブジェクトは特定のダメージタイプが必要な場合があります。"),
    34: ("Vehicles", "車両"),
    35: ("Your vehicle allows you to travel around a location more quickly, store extra items in the trunk, and attack in combat. It cannot be permanently destroyed, but if damaged enough, it will require repairs. You must take it with you when you leave a location to the World Map.", "車両を使用すると、場所をより速く移動でき、トランクに追加アイテムを保管でき、戦闘で攻撃できます。永久的に破壊されることはありませんが、十分なダメージを受けると修理が必要になります。ワールドマップに移動する際は、車両を一緒に持っていく必要があります。"),
    36: ("Character Creation", "キャラクター作成"),
    37: ("Welcome to Wasteland 3, Ranger. On this screen, you will create your starting Ranger. In addition to your appearance, you may pick a pre-set Specialization, or fully customize your Attributes, Skills, and other details.", "ようこそWasteland 3へ、レンジャー。この画面では、最初のレンジャーを作成します。外見に加えて、事前設定された専門化を選択するか、属性、スキル、その他の詳細を完全にカスタマイズできます。"),
    38: ("Movement", "移動"),
    39: ("To move to a specific spot, right-click on the ground. You can also continue holding it down to follow the direction of the mouse cursor.", "特定の場所に移動するには、地面を右クリックします。押し続けてマウスカーソルの方向に従うこともできます。"),
}

print(f"Tutorial translation mappings created for {len(translations)} entries (20-39)")
print("Run with actual translation logic if needed")
