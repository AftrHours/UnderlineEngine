# Little Women chapters 1–3: release 1.1.0 vs v2, in reading order

How to read: every sentence underlined by either version appears once, in book order, with the underlined phrases in bold. Below it are each version's references.

- **Release 1.1.0**: the Little Women seed bundled with the iRead app (`UnderlineSeed/755d6…`, engineVersion 4), produced by the app on the model path (Foundation Models), `NLEmbedding`, no IDF.
- **v2**: branch `link-quality`, rules path, `NLContextualEmbedding`, book-level IDF, score threshold 0.60, rare share 0.4%, at the time of the comparison (R7 configuration).
- Verdicts: ✅ linked · 🟡 partial · ❌ not linked. Claude's verdicts, not ground truth. The seed stores book-level sentence numbers only, so S numbers here come from the harness's sentence split; "S?" means the reference was not found in the same chapter.

## Summary

| Chapter | Release: underlines | Release: ✅ / 🟡 / ❌ | v2: underlines | v2: ✅ / 🟡 / ❌ |
|---|---|---|---|---|
| 1 | 35 | 6 / 2 / 27 | 19 | 9 / 1 / 9 |
| 2 | 43 | 11 / 1 / 31 | 12 | 6 / 0 / 6 |
| 3 | 55 | 18 / 5 / 32 | 23 | 16 / 0 / 7 |
| Total | 133 | 35 / 8 / 90 | 54 | 31 / 1 / 22 |

In the release, 15 underlines are shorter than 3 words (mostly names: "Meg", "Mother", "Mrs. March"), and 14 of them are ❌. v2 has none, because every phrase needs 3+ words.

## Chapter 1: Playing Pilgrims

### S5

> The four young faces on which the firelight shone brightened at the cheerful words, but darkened again as Jo said sadly, "We haven't got Father, and shall not have him for a long time."

- Release ❌ *haven’t got Father* → S?: CHAPTER ONE
- v2: none

### S7

> Nobody spoke for a minute; then Meg said in an altered tone, "You know the reason Mother proposed not having any presents this Christmas was because it is going to be a hard winter for everyone; and she **thinks we ought not to spend money for pleasure**, when our men are suffering so in the army.

- Release ❌ *thinks we ought not to spend money for pleasure* → S3: “I don’t think it’s fair for some girls to have plenty of pretty things, and other girls nothing at all,” added little Amy, with an injured sniff.
- v2: none

### S23

> And Beth **looked at her rough hands with a sigh that any one could hear that time**.

- Release 🟡 *looked at her rough hands with a sigh that any one could hear that time* → S14: “I planned to spend mine in new music,” said Beth, with a little sigh, which no one heard but the hearth brush and kettle-holder.
- v2: none

### S25

> "If you mean libel, I'd say so, and not talk about labels, as if Papa was a pickle bottle," advised Jo, laughing.

- Release ❌ *I’d say so* → S13: I’ve wanted it so long,” said Jo, who was a bookworm.
- v2: none

### S31

> How happy and good we'd be, if we **had no worries**!"

- Release 🟡 *had no worries* → S20: “How would you like to be shut up for hours with a nervous, fussy old lady, who keeps you trotting, is never satisfied, and worries you till you’re ready to fly out the window or cry?”
- v2: none

### S36

> For though we do have to work, we **make fun of ourselves**, and are a pretty jolly set, as Jo would say."

- Release ✅ *make fun of ourselves* → S17: Let’s each buy what we want, and have a little fun; I’m sure we work hard enough to earn it,” cried Jo, examining the heels of her shoes in a gentlemanly manner.
- v2: none

### S39

> Jo immediately sat up, put her hands in her pockets, and **began to whistle**.

- Release ❌ *began to whistle* → S13: I’ve wanted it so long,” said Jo, who was a bookworm.
- v2: none

### S46

> "Really, girls, you are both to be blamed," said Meg, **beginning to lecture in her elder-sisterly fashion**.

- Release ❌ *beginning to lecture in her elder-sisterly fashion* → S18: “I know I do—teaching those tiresome children nearly all day, when I’m longing to enjoy myself at home,” began Meg, in the complaining tone again.
- v2: none

### S47

> "You **are old enough to leave off boyish tricks**, and to behave better, Josephine.

- Release: none
- v2 ✅ *are old enough to leave off boyish tricks* → S41: It's so boyish!"

### S54

> And it's worse than ever now, for I'm dying to go and **fight with Papa**.

- Release: none
- v2 ❌ *fight with Papa* → S29: Don't you wish we had the money Papa lost when we were little, Jo?

### S58

> It's too bad, but it can't be helped.

- Release ❌ *can’t be helped* → S53: I can’t get over my disappointment in not being a boy.
- v2: none

### S63

> But your absurd words **are as bad as Jo's slang**."

- Release ✅ *are as bad as Jo’s slang* → S37: “Jo does use such slang words!”
- v2 ✅ *are as bad as Jo's slang* → S37: "Jo does use such slang words!"

### S68

> It was a comfortable room, though the carpet was faded and the furniture very plain, for a good picture or two hung on the walls, books filled the recesses, chrysanthemums and Christmas roses **bloomed in the windows**, and a pleasant atmosphere of home peace pervaded it.

- Release ❌ *bloomed in the windows* → S65: asked Beth, ready to share the lecture.
- v2: none

### S72

> Her long, thick hair was her one beauty, but it **was usually bundled into a net**, to be out of her way.

- Release: none
- v2 ✅ *was usually bundled into a net* → S50: And if turning up my hair makes me one, I'll wear it in two tails till I'm twenty," cried Jo, pulling off her net, and shaking down a chestnut mane.

### S79

> The clock struck six and, **having swept up the hearth**, Beth put a pair of slippers down to warm.

- Release: none
- v2 ❌ *having swept up the hearth* → S14: "I planned to spend mine in new music," said Beth, with a little sigh, which no one heard but the hearth brush and kettle-holder.

### S80

> Somehow the sight of the old shoes had a good effect upon the girls, for **Mother** was coming, and everyone brightened to welcome her.

- Release ❌ *Mother* → S4: “We’ve got Father and Mother, and each other,” said Beth contentedly from her corner.
- v2: none

### S82

> "They **are quite worn out**.

- Release ❌ *are quite worn out* → S35: Well, I think we are.
- v2: none

### S84

> "I **thought I'd get her some with my dollar**," said Beth.

- Release: none
- v2 ✅ *thought I'd get her some with my dollar* → S11: We've each got a dollar, and the army wouldn't be much helped by our giving that.

### S87

> "I'm the oldest," began Meg, but Jo cut in with a decided, "I'm the man of the family now Papa is away, and I shall provide the slippers, for he told me to take special care of Mother while he was gone."

- Release ❌ *I’m the man of the family now Papa is away* → S66: “You’re a dear, and nothing else,” answered Meg warmly, and no one contradicted her, for the ‘Mouse’ was the pet of the family.
- v2: none

### S96

> She likes it, and it won't cost much, so **I'll have some left to buy my pencils**," added Amy.

- Release ❌ *won’t cost much* → S16: “Mother didn’t say anything about our money, and she won’t wish us to give up everything.
- v2 ✅ *I'll have some left to buy my pencils* → S15: "I shall get a nice box of Faber's drawing pencils; I really need them," said Amy decidedly.

### S97

> "How **will we give the things**?"

- Release ❌ *will we give the things* → S11: We’ve each got a dollar, and the army wouldn’t be much helped by our giving that.
- v2: none

### S103

> I liked the things and the kisses, but it **was dreadful to have you sit looking at me while I opened the bundles**," said Beth, who was toasting her face and the bread for tea at the same time.

- Release: none
- v2 ✅ *was dreadful to have you sit looking at me while I opened the bundles* → S99: "Put them on the table, and bring her in and see her open the bundles.

### S112

> **Come here, Amy**, and do the fainting scene, for you are as stiff as a poker in that."

- Release: none
- v2 ❌ *Come here, Amy* → S64: "If Jo is a tomboy and Amy a goose, what am I, please?"

### S113

> "I can't help it.

- Release ❌ *can’t help it* → S58: It’s too bad, but it can’t be helped.
- v2: none

### S128

> **Come on, **Meg****."

- Release ❌ *Come on, Meg* → S?: asked Meg.
- Release ❌ *Meg* → S128: Come on, Meg.”
- v2: none

### S134

> "I don't see how you can write and **act such splendid things, Jo**.

- Release ❌ *act such splendid things, Jo* → S37: “Jo does use such slang words!”
- v2 ❌ *act such splendid things, Jo* → S37: "Jo does use such slang words!"

### S139

> I always **wanted to do the killing part**.

- Release ❌ *wanted to do the killing part* → S13: I’ve wanted it so long,” said Jo, who was a bookworm.
- v2: none

### S142

> "No, **it's the toasting fork, with Mother's shoe on it instead of the bread**.

- Release: none
- v2 🟡 *it's the toasting fork, with Mother's shoe on it instead of the bread* → S103: I liked the things and the kisses, but it was dreadful to have you sit looking at me while I opened the bundles," said Beth, who was toasting her face and the bread for tea at the same time.

### S148

> There **was so much to do**, **getting the boxes ready to go tomorrow**, that I didn't come home to dinner.

- Release ❌ *was so much to do* → S106: There is so much to do about the play for Christmas night,” said Jo, marching up and down, with her hands behind her back, and her nose in the air.
- v2 ❌ *getting the boxes ready to go tomorrow* → S105: We must go shopping tomorrow afternoon, Meg.

### S153

> While making these maternal inquiries **Mrs. March** got her wet things off, her warm slippers on, and sitting down in the easy chair, drew Amy to her lap, preparing to enjoy the happiest hour of her busy day.

- Release ❌ *Mrs. March* → S153: While making these maternal inquiries Mrs. March got her wet things off, her warm slippers on, and sitting down in the easy chair, drew Amy to her lap, preparing to enjoy the happiest hour of her busy day.
- v2: none

### S166

> Don't stop to quirk your little finger and simper over your plate, Amy," cried Jo, choking on her tea and **dropping her bread, butter side down**, on the carpet in her haste to **get at the treat**.

- Release ✅ *dropping her bread, butter side down* → S155: Meg arranged the tea table, Jo brought wood and set chairs, dropping, over-turning, and clattering everything she touched.
- v2 ✅ *get at the treat* → S157: As they gathered about the table, Mrs. March said, with a particularly happy face, "I've got a treat for you after supper."

### S170

> Or a nurse, so I could be near him and **help him," exclaimed Jo, with a groan**.

- Release: none
- v2 ❌ *help him," exclaimed Jo, with a groan* → S125: Jo gave a despairing groan, and Meg laughed outright, while Beth let her bread burn as she watched the fun with interest.

### S172

> "**When will he come home, Marmee**?"

- Release: none
- v2 ❌ *When will he come home, Marmee* → S83: Marmee must have a new pair."

### S176

> Now come and **hear the letter**."

- Release ✅ *hear the letter* → S159: A letter!
- v2: none

### S184

> I know they will remember all I said to them, that they will be loving children to you, will do their duty faithfully, **fight their bosom enemies bravely**, and conquer themselves so beautifully that when I come back to them I may be fonder and prouder than ever of my little women."

- Release ✅ *fight their bosom enemies bravely* → S54: And it’s worse than ever now, for I’m dying to go and fight with Papa.
- v2: none

### S186

> Jo wasn't ashamed of the great tear that dropped off the end of her nose, and Amy never **minded the rumpling of her curls as she hid her face on her mother's shoulder** and sobbed out, "I am a selfish girl!

- Release: none
- v2 ❌ *minded the rumpling of her curls as she hid her face on her mother's shoulder* → S77: A regular snow maiden, with blue eyes, and yellow hair curling on her shoulders, pale and slender, and always carrying herself like a young lady mindful of her manners.

### S189

> "I think too much of my looks and hate to work, but won't any more, if I **can help it**."

- Release ❌ *can help it* → S113: “I can’t help it.
- v2: none

### S191

> Beth said nothing, but **wiped away her tears with the blue army sock** and began to knit with all her might, losing no time in doing the duty that lay nearest her, while she resolved in her quiet little soul to be all that Father hoped to find her when the year brought round the happy coming home.

- Release: none
- v2 ✅ *wiped away her tears with the blue army sock* → S56: And Jo shook the blue army sock till the needles rattled like castanets, and her ball bounded across the room.

### S193

> Nothing delighted you more than to have me tie my piece bags on your backs for burdens, **give you hats and sticks and rolls of paper**, and let you travel through the house from the cellar, which was the City of Destruction, up, up, to the housetop, where you had all the lovely things you could collect to make a Celestial City."

- Release ❌ *give you hats and sticks and rolls of paper* → S97: “How will we give the things?”
- v2: none

### S195

> "I **liked the place where the bundles fell off** and tumbled downstairs," said Meg.

- Release: none
- v2 ❌ *liked the place where the bundles fell off* → S103: I liked the things and the kisses, but it was dreadful to have you sit looking at me while I opened the bundles," said Beth, who was toasting her face and the bread for tea at the same time.

### S198

> "We never **are too old for this, my dear**, because it is a play we are playing all the time in one way or another.

- Release ❌ *are too old for this, my dear* → S47: “You are old enough to leave off boyish tricks, and to behave better, Josephine.
- v2: none

### S199

> Our burdens are here, our road is before us, and the longing for goodness and happiness is the guide that leads us through many troubles and mistakes to the peace which **is a true Celestial City**.

- Release: none
- v2 ✅ *is a true Celestial City* → S193: Nothing delighted you more than to have me tie my piece bags on your backs for burdens, give you hats and sticks and rolls of paper, and let you travel through the house from the cellar, which was the City of Destruction, up, up, to the housetop, where you had all the lovely things you could collect to make a Celestial City."

### S202

> **Where are our bundles**?"

- Release ✅ *Where are our bundles* → S99: “Put them on the table, and bring her in and see her open the bundles.
- v2: none

### S208

> Beth's bundle **was such a funny one that everybody wanted to laugh**, but nobody did, for it would have hurt her feelings very much.

- Release ❌ *was such a funny one that everybody wanted to laugh* → S45: “Birds in their little nests agree,” sang Beth, the peacemaker, with such a funny face that both sharp voices softened to a laugh, and the “pecking” ended for that time.
- v2: none

### S210

> "It is only another name for trying to be good, and the story may help us, for though we do want to be good, it's hard work and we forget, and don't do our best."

- Release ❌ *it’s hard work* → S52: It’s bad enough to be a girl, anyway, when I like boy’s games and work and manners!
- v2: none

### S211

> "We were in the Slough of Despond tonight, and **Mother** came and pulled us out as Help did in the book.

- Release ❌ *Mother* → S?: “Really, Mother?
- v2: none

### S218

> They adopted Jo's plan of dividing the long seams into four parts, and **calling the quarters Europe, Asia, Africa, and America**, and in that way got on capitally, especially when they talked about the different countries as they stitched their way through them.

- Release ❌ *calling the quarters Europe, Asia, Africa, and America* → S149: Has anyone called, Beth?
- v2: none

### S219

> At nine they stopped work, and **sang, as usual**, before they went to bed.

- Release ❌ *sang, as usual* → S45: “Birds in their little nests agree,” sang Beth, the peacemaker, with such a funny face that both sharp voices softened to a laugh, and the “pecking” ended for that time.
- v2: none

## Chapter 2: A Merry Christmas

### S6

> Presently **Beth** and **Amy** woke to rummage and find their little books also, one dove-colored, the other blue, and all **sat looking at** and talking about them, while the east grew rosy with the coming day.

- Release ❌ *sat looking at* → S?: CHAPTER TWO
- Release ❌ *Amy* → S14: Come, Amy, let’s do as they do.
- Release ❌ *Beth* → S?: Strike up, Beth!
- v2: none

### S9

> We used to be faithful about it, but since Father went away and all this war trouble unsettled us, we **have neglected many things**.

- Release ❌ *have neglected many things* → S?: CHAPTER TWO
- v2: none

### S11

> Then she opened her new book and **began to read**.

- Release ✅ *began to read* → S8: “Girls,” said Meg seriously, looking from the tumbled head beside her to the two little night-capped ones in the room beyond, “Mother wants us to read and love and mind these books, and we must begin at once.
- v2: none

### S16

> "I'm glad mine is blue," said Amy. and then the rooms were very still while the pages were softly turned, and the winter sunshine crept in to touch the bright heads and serious faces with a Christmas greeting.

- Release ✅ *I’m glad mine is blue* → S6: Presently Beth and Amy woke to rummage and find their little books also, one dove-colored, the other blue, and all sat looking at and talking about them, while the east grew rosy with the coming day.
- v2: none

### S22

> "She will be back soon, I think, so fry your cakes, and have everything ready," said Meg, looking over the presents which were collected in a basket and kept under the sofa, ready to **be produced at the proper time**.

- Release ❌ *be produced at the proper time* → S14: Come, Amy, let’s do as they do.
- v2: none

### S27

> Hannah washed and ironed them for me, and I **marked them all myself**," said Beth, looking proudly at the somewhat uneven letters which had cost her such labor.

- Release ❌ *marked them all myself* → S14: Come, Amy, let’s do as they do.
- v2: none

### S34

> "It's all right, dear, and a very pretty idea, quite sensible too, for no one **can ever mistake now**.

- Release ❌ *can ever mistake now* → S?: How funny!”
- v2: none

### S37

> **Hide the basket, quick**!"

- Release ✅ *Hide the basket, quick* → S22: “She will be back soon, I think, so fry your cakes, and have everything ready,” said Meg, looking over the presents which were collected in a basket and kept under the sofa, ready to be produced at the proper time.
- v2: none

### S41

> asked Meg, surprised to see, by her hood and cloak, **that lazy Amy had been out so early**.

- Release ✅ *that lazy Amy had been out so early* → S39: Amy came in hastily, and looked rather abashed when she saw her sisters all waiting for her.
- v2: none

### S42

> "Don't laugh at me, Jo!

- Release ❌ *Don’t laugh at me, Jo* → S38: cried Jo, as a door slammed and steps sounded in the hall.
- v2: none

### S45

> As she spoke, Amy **showed the handsome flask which replaced the cheap one**, and looked so earnest and humble in her little effort to forget herself that Meg hugged her on the spot, and Jo pronounced her 'a trump', while Beth ran to the window, and picked her finest rose to ornament the stately bottle.

- Release: none
- v2 ✅ *showed the handsome flask which replaced the cheap one* → S24: she added, as the little flask did not appear.

### S46

> "You see I felt ashamed of my present, after reading and talking about being good this morning, so I ran round the corner and changed it the minute I was up, and I'm so glad, for mine **is the handsomest now**."

- Release ❌ *is the handsomest now* → S32: “Isn’t that right?
- v2: none

### S47

> Another bang of the street door **sent the basket under the sofa, and the girls to the table, eager for breakfast**.

- Release ✅ *sent the basket under the sofa, and the girls to the table, eager for breakfast* → S22: “She will be back soon, I think, so fry your cakes, and have everything ready,” said Meg, looking over the presents which were collected in a basket and kept under the sofa, ready to be produced at the proper time.
- v2 ✅ *sent the basket under the sofa, and the girls to the table, eager for breakfast* → S22: "She will be back soon, I think, so fry your cakes, and have everything ready," said Meg, looking over the presents which were collected in a basket and kept under the sofa, ready to be produced at the proper time.

### S51

> We read some, and mean to every day," they all **cried in chorus**.

- Release ❌ *cried in chorus* → S38: cried Jo, as a door slammed and steps sounded in the hall.
- v2: none

### S53

> I'm glad you began at once, and hope you will keep on.

- Release ✅ *I’m glad you began at once* → S46: “You see I felt ashamed of my present, after reading and talking about being good this morning, so I ran round the corner and changed it the minute I was up, and I’m so glad, for mine is the handsomest now.”
- v2: none

### S59

> They were all unusually hungry, having waited nearly an hour, and for a minute no one spoke, only a minute, for Jo exclaimed impetuously, "I'm so glad you came before we began!"

- Release ❌ *I’m so glad you came before we began* → S53: I’m glad you began at once, and hope you will keep on.
- v2: none

### S64

> "I thought you'd do it," said Mrs. March, **smiling as if satisfied**.

- Release ❌ *smiling as if satisfied* → S32: “Isn’t that right?
- v2: none

### S66

> They **were soon ready**, and the procession set out.

- Release ❌ *were soon ready* → S22: “She will be back soon, I think, so fry your cakes, and have everything ready,” said Meg, looking over the presents which were collected in a basket and kept under the sofa, ready to be produced at the proper time.
- v2: none

### S67

> Fortunately it was early, and they **went through back streets**, so few people saw them, and no one laughed at the queer party.

- Release: none
- v2 ❌ *went through back streets* → S47: Another bang of the street door sent the basket under the sofa, and the girls to the table, eager for breakfast.

### S69

> How the big eyes stared and the blue lips **smiled as the girls went in**.

- Release ❌ *smiled as the girls went in* → S64: “I thought you’d do it,” said Mrs. March, smiling as if satisfied.
- v2: none

### S72

> **said the poor woman**, crying for joy.

- Release ✅ *said the poor woman* → S55: Not far away from here lies a poor woman with a little newborn baby.
- v2: none

### S82

> **That was a very happy breakfast**, though they didn't get any of it.

- Release: none
- v2 ✅ *That was a very happy breakfast* → S58: My girls, will you give them your breakfast as a Christmas present?"

### S84

> "That's loving our neighbor better than ourselves, and I like it," said **Meg**, as they set out their presents while their mother was upstairs collecting clothes for the poor Hummels.

- Release ❌ *Meg* → S?: “How good Meg is!
- v2: none

### S91

> Beth played her gayest march, Amy **threw open the door**, and Meg enacted escort with great dignity.

- Release ✅ *threw open the door* → S88: Open the door, Amy!
- v2: none

### S92

> Mrs. March **was both surprised** and touched, and smiled with her eyes full as she examined her presents and read the little notes which accompanied them.

- Release: none
- v2 ❌ *was both surprised* → S41: asked Meg, surprised to see, by her hood and cloak, that lazy Amy had been out so early.

### S110

> After pacing to and fro in much agitation, he struck his forehead, and burst out in a wild strain, singing of his hatred for Roderigo, his love for Zara, and his pleasing resolution to **kill the one** and win the other.

- Release ❌ *kill the one* → S28: “Bless the child!
- v2: none

### S118

> Born of roses, **fed on dew**, Charms and potions canst thou brew?

- Release ❌ *fed on dew* → S77: The girls meantime spread the table, set the children round the fire, and fed them like so many hungry birds, laughing, talking, and trying to understand the funny broken English.
- v2: none

### S119

> **Bring me here**, with elfin speed, The fragrant philter which I need.

- Release ✅ *Bring me here* → S116: Hagar, in a fine dramatic melody, promised both, and proceeded to call up the spirit who would bring the love philter.
- v2: none

### S120

> **Make it sweet and swift and strong**, Spirit, answer now my song!

- Release ❌ *Make it sweet and swift and strong* → S94: There was a good deal of laughing and kissing and explaining, in the simple, loving fashion which makes these home festivals so pleasant at the time, so sweet to remember long afterward, and then all fell to work.
- v2: none

### S124

> **Take the magic spell**, And use it well, Or its power will vanish soon!

- Release ❌ *Take the magic spell* → S31: cried Jo, taking one up.
- v2: none

### S127

> Having warbled his thanks and put the potions in his boots, Hugo departed, and Hagar informed the audience that as he had killed a few of her friends in times past, she had cursed him, and intends to thwart his plans, and **be revenged on him**.

- Release ❌ *be revenged on him* → S54: But I want to say one word before we sit down.
- v2: none

### S131

> A tower rose to the ceiling, halfway up appeared a window with a lamp burning in it, and behind the white curtain appeared Zara in a lovely blue and silver dress, **waiting for Roderigo**.

- Release ❌ *waiting for Roderigo* → S115: Hugo demanded a potion to make Zara adore him, and one to destroy Roderigo.
- v2 ❌ *waiting for Roderigo* → S115: Hugo demanded a potion to make Zara adore him, and one to destroy Roderigo.

### S152

> She hears him coming and hides, sees him put the potions into two cups of wine and bid the timid little servant, "Bear them to the captives in their cells, and **tell them I shall come anon**."

- Release ❌ *tell them I shall come anon* → S142: I told you so!”
- v2: none

### S156

> This **was a truly thrilling scene**, though some persons might have thought that the sudden tumbling down of a quantity of long red hair rather marred the effect of the villain's death.

- Release: none
- v2 ❌ *was a truly thrilling scene* → S98: The big chamber was the scene of many innocent revels.

### S159

> Just as the dagger is at his heart, a lovely song **is sung under his window**, informing him that Zara is true but in danger, and he can save her if he will.

- Release 🟡 *is sung under his window* → S133: Kneeling at the foot of the tower, he sang a serenade in melting tones.
- v2: none

### S160

> A key is thrown in, which unlocks the door, and in a spasm of rapture he **tears off his chains** and rushes away to find and rescue his lady love.

- Release: none
- v2 ✅ *tears off his chains* → S150: A stout little retainer came in with chains and led them away, looking very much frightened and evidently forgetting the speech he ought to have made.

### S163

> Don Pedro refuses, because he **is not rich**.

- Release ❌ *is not rich* → S96: Being still too young to go often to the theater, and not rich enough to afford any great outlay for private performances, the girls put their wits to work, and necessity being the mother of invention, made whatever they needed.
- v2: none

### S164

> They shout and gesticulate tremendously but cannot agree, and Rodrigo **is about to bear away the exhausted Zara, when the timid servant enters with a letter and a bag from Hagar**, who has mysteriously disappeared.

- Release: none
- v2 ✅ *is about to bear away the exhausted Zara, when the timid servant enters with a letter and a bag from Hagar* → S152: She hears him coming and hides, sees him put the potions into two cups of wine and bid the timid little servant, "Bear them to the captives in their cells, and tell them I shall come anon."

### S171

> The excitement had hardly subsided when Hannah appeared, with "**Mrs. March**'s compliments, and would the ladies walk down to supper."

- Release ❌ *Mrs. March* → S64: “I thought you’d do it,” said Mrs. March, smiling as if satisfied.
- v2: none

### S173

> It was like **Marmee** to get up a little treat for them, but anything so fine as this was unheard of since the departed days of plenty.

- Release ❌ *Marmee* → S?: “Merry Christmas, Marmee!
- v2: none

### S174

> There was ice cream, actually two dishes of it, pink and white, and cake and fruit and **distracting French bonbons and, in the middle of the table, four great bouquets of hot house flowers**.

- Release: none
- v2 ❌ *distracting French bonbons and, in the middle of the table, four great bouquets of hot house flowers* → S85: Not a very splendid show, but there was a great deal of love done up in the few little bundles, and the tall vase of red roses, white chrysanthemums, and trailing vines, which stood in the middle, gave quite an elegant air to the table.

### S183

> Old Mr. **Laurence** sent it," replied Mrs. March.

- Release ❌ *Laurence* → S183: Old Mr. Laurence sent it,” replied Mrs. March.
- v2: none

### S191

> I **could not refuse**, and so you have a little feast at night to make up for the bread-and-milk breakfast."

- Release ❌ *could not refuse* → S163: Don Pedro refuses, because he is not rich.
- v2: none

### S192

> "**That boy put it into his head**, I know he did!

- Release ✅ *That boy put it into his head* → S185: What in the world put such a thing into his head?
- v2: none

### S197

> "My mother knows old Mr. Laurence, but says he's very proud and **doesn't like to mix with his neighbors**.

- Release ❌ *Mother* → S?: “There’s Mother.
- v2 ❌ *doesn't like to mix with his neighbors* → S84: "That's loving our neighbor better than ourselves, and I like it," said Meg, as they set out their presents while their mother was upstairs collecting clothes for the poor Hummels.

### S201

> "Our cat ran away once, and he **brought her back**, and we talked over the fence, and were getting on capitally, all about cricket, and so on, when he saw Meg coming, and walked off.

- Release ❌ *brought her back* → S119: Bring me here, with elfin speed,
- v2: none

### S204

> He **brought the flowers himself**, and I should have asked him in, if I had been sure what was going on upstairs.

- Release ❌ *brought the flowers himself* → S119: Bring me here, with elfin speed,
- v2: none

### S206

> "It's a mercy you didn't, Mother!"

- Release ❌ *It’s a mercy you didn’t, Mother* → S200: Mother says he’s very nice, though he never speaks to us girls.”
- v2: none

### S211

> "I never **had such a fine bouquet before**!

- Release: none
- v2 ✅ *had such a fine bouquet before* → S174: There was ice cream, actually two dishes of it, pink and white, and cake and fruit and distracting French bonbons and, in the middle of the table, four great bouquets of hot house flowers.

### S213

> And Meg **examined her flowers with great interest**.

- Release ✅ *examined her flowers with great interest* → S174: There was ice cream, actually two dishes of it, pink and white, and cake and fruit and distracting French bonbons and, in the middle of the table, four great bouquets of hot house flowers.
- v2: none

## Chapter 3: The Laurence Boy

### S6

> This was Jo's favorite refuge, and here she loved to retire with half a dozen russets and a nice book, to enjoy the quiet and the society of a pet rat who lived near by and didn't mind her a particle.

- Release ❌ *was Jo’s favorite refuge* → S?: Jo!
- v2: none

### S12

> cried Meg, **waving the precious paper** and then proceeding to read it with girlish delight.

- Release ❌ *waving the precious paper* → S?: CHAPTER THREE
- v2: none

### S31

> "Then I'll stay still.

- Release ✅ *I’ll stay still* → S24: “You must sit still all you can and keep your back out of sight.
- v2: none

### S37

> Can't you make them do?"

- Release ✅ *Can’t you make them do* → S30: You can’t dance without them, and if you don’t I should be so mortified.”
- v2: none

### S42

> Don't you see?"

- Release ❌ *Don’t you see* → S?: Only see!
- v2: none

### S48

> Only don't stain it, and do behave nicely.

- Release ✅ *don’t stain it* → S38: “I can hold them crumpled up in my hand, so no one will know how stained they are.
- v2: none

### S53

> Now go and **answer your note**, and let me finish this splendid story."

- Release ❌ *answer your note* → S?: answered Jo with her mouth full.
- v2: none

### S54

> So Meg went away to 'accept with thanks', look over her dress, and sing blithely as she did up her one real lace frill, while Jo finished her story, her four apples, and **had a game of romps with Scrabble**.

- Release: none
- v2 ✅ *had a game of romps with Scrabble* → S7: As Meg appeared, Scrabble whisked into his hole.

### S56

> Simple as the toilets were, there was a great deal of running up and down, laughing and talking, and at one time a strong smell of **burned hair pervaded the house**.

- Release ✅ *burned hair pervaded the house* → S23: The burn shows badly, and I can’t take any out.”
- v2: none

### S63

> "There, now I'll take off the papers and you'll see a cloud of little ringlets," said Jo, **putting down the tongs**.

- Release: none
- v2 ✅ *putting down the tongs* → S57: Meg wanted a few curls about her face, and Jo undertook to pinch the papered locks with a pair of hot tongs.

### S64

> She did take off the papers, but no cloud of ringlets appeared, for the hair **came with the papers**, and the horrified hairdresser laid a row of little scorched bundles on the bureau before her victim.

- Release ✅ *came with the papers* → S63: “There, now I’ll take off the papers and you’ll see a cloud of little ringlets,” said Jo, putting down the tongs.
- v2: none

### S70

> wailed **Meg**, looking with despair at the uneven frizzle on her forehead.

- Release ❌ *Meg* → S?: sighed Meg.
- v2: none

### S74

> I'm so sorry, but the tongs **were too hot**, and so I've made a mess," groaned poor Jo, regarding the little black pancakes with tears of regret.

- Release ❌ *were too hot* → S?: I’m spoiled!
- v2: none

### S76

> Just frizzle it, and tie your ribbon so the ends come on your forehead a bit, and it **will look like the last fashion**.

- Release ✅ *will look like the last fashion* → S70: wailed Meg, looking with despair at the uneven frizzle on her forehead.
- v2: none

### S79

> I wish I'd let my hair alone," cried Meg petulantly.

- Release 🟡 *wish I’d let my hair alone* → S?: My hair, oh, my hair!”
- v2: none

### S80

> "So do I, it **was so smooth and pretty**.

- Release ❌ *was so smooth and pretty* → S20: “I’m sure our pops look like silk, and they are nice enough for us.
- v2: none

### S85

> Each put on one nice light glove, and **carried one soiled one**, and all pronounced the effect "quite easy and fine".

- Release ✅ *carried one soiled one* → S41: I’ll tell you how we can manage, each wear one good one and carry a bad one.
- v2: none

### S90

> As the gate clashed behind them, a voice **cried from a window**...

- Release ❌ *cried from a window* → S?: cried Meg at the foot of the garret stairs.
- v2: none

### S92

> **Have you you both got nice pocket handkerchiefs**?"

- Release ❌ *Have you you both got nice pocket handkerchiefs* → S20: “I’m sure our pops look like silk, and they are nice enough for us.
- v2: none

### S93

> "Yes, yes, spandy nice, and Meg **has cologne on hers**," cried Jo, adding with a laugh as they went on, "I do believe Marmee would ask that if we were all running away from an earthquake."

- Release ❌ *has cologne on hers* → S2: Where are you?”
- v2: none

### S97

> And **does my hair look very bad**?"

- Release 🟡 *does my hair look very bad* → S?: My hair, oh, my hair!”
- v2: none

### S98

> said **Meg**, as she turned from the glass in Mrs. Gardiner's dressing room after a prolonged prink.

- Release ❌ *Meg* → S?: sighed Meg.
- v2: none

### S101

> returned Jo, **giving her collar a twitch and her head a hasty brush**.

- Release: none
- v2 ✅ *giving her collar a twitch and her head a hasty brush* → S84: Jo in maroon, with a stiff, gentlemanly linen collar, and a white chrysanthemum or two for her only ornament.

### S115

> She could not roam about and amuse herself, for the burned breadth would show, so she **stared at people rather forlornly till the dancing began**.

- Release: none
- v2 ❌ *stared at people rather forlornly till the dancing began* → S32: I don't care much for company dancing.

### S124

> I only came here because I don't know many people and **felt rather strange at first**, you know."

- Release 🟡 *felt rather strange at first* → S111: Meg knew Sallie and was at her ease very soon, but Jo, who didn’t care much for girls or girlish gossip, stood about, with her back carefully against the wall, and felt as much out of place as a colt in a flower garden.
- v2: none

### S130

> **That put Jo at her ease** and she laughed too, as she said, in her heartiest way, "We **did have such a good time over your nice Christmas present**."

- Release ❌ *did have such a good time over your nice Christmas present* → S87: “Have a good time, dearies!”
- v2 ✅ *That put Jo at her ease* → S111: Meg knew Sallie and was at her ease very soon, but Jo, who didn't care much for girls or girlish gossip, stood about, with her back carefully against the wall, and felt as much out of place as a colt in a flower garden.

### S132

> "But you put it into his head, didn't you, now?"

- Release ❌ *didn’t you, now* → S42: Don’t you see?”
- v2: none

### S136

> But I am not Miss March, I'm only Jo," returned the young lady.

- Release ❌ *I’m only Jo* → S?: Jo!
- v2: none

### S137

> "**I'm not Mr. Laurence**, I'm only Laurie."

- Release: none
- v2 ✅ *I'm not Mr. Laurence* → S135: "Nicely, thank you, Mr. Laurence.

### S139

> "My first name is Theodore, but I don't like it, for the fellows called me Dora, so I **made them say Laurie instead**."

- Release ✅ *made them say Laurie instead* → S137: “I’m not Mr. Laurence, I’m only Laurie.”
- v2: none

### S142

> How **did you make the boys stop calling you Dora**?"

- Release ✅ *did you make the boys stop calling you Dora* → S139: “My first name is Theodore, but I don’t like it, for the fellows called me Dora, so I made them say Laurie instead.”
- v2 ✅ *did you make the boys stop calling you Dora* → S139: "My first name is Theodore, but I don't like it, for the fellows called me Dora, so I made them say Laurie instead."

### S144

> "I can't thrash Aunt March, so I suppose I shall have to bear it."

- Release ❌ *can’t thrash Aunt March* → S?: I can’t go!
- v2: none

### S150

> Don't you dance?"

- Release ✅ *Don’t you dance* → S146: “Don’t you like to dance, Miss Jo?”
- v2: none

### S152

> You see I've been abroad a good many years, and **haven't been into company enough yet to know how you do things here**."

- Release: none
- v2 ❌ *haven't been into company enough yet to know how you do things here* → S32: I don't care much for company dancing.

### S157

> Laurie didn't seem to know where to begin, but Jo's eager questions soon set him going, and he **told her how he had been at school in Vevay**, where the boys never wore hats and had a fleet of boats on the lake, and for holiday fun went on walking trips about Switzerland with their teachers.

- Release ✅ *told her how he had been at school in Vevay* → S155: “Oh, tell me about it!
- v2: none

### S161

> "We **spent last winter there**."

- Release: none
- v2 ❌ *spent last winter there* → S36: She said when you spoiled the others that she shouldn't get you any more this winter.

### S165

> I **can read it**, but can't pronounce."

- Release ❌ *can read it* → S12: cried Meg, waving the precious paper and then proceeding to read it with girlish delight.
- v2: none

### S168

> **Let me see ... you said**, 'Who is the young lady in the pretty slippers', didn't you?"

- Release ❌ *Let me see ... you said* → S42: Don’t you see?”
- v2: none

### S170

> "It's my sister Margaret, and you **knew it was**!

- Release ❌ *knew it was* → S119: “Dear me, I didn’t know anyone was here!”
- v2: none

### S175

> Laurie's bashfulness soon wore off, for Jo's gentlemanly demeanor amused and set him at his ease, and Jo **was her merry self again**, because her dress was forgotten and nobody **lifted their eyebrows at her**.

- Release ❌ *was her merry self again* → S96: Is my sash right?
- v2 ✅ *lifted their eyebrows at her* → S103: I'll lift my eyebrows if any thing is wrong, and nod if you are all right.

### S177

> "Curly black hair, brown skin, big black eyes, handsome nose, fine teeth, small hands and feet, taller than I **am, very polite, for a boy, and altogether jolly**.

- Release 🟡 *am, very polite, for a boy, and altogether jolly* → S126: The boy sat down again and looked at his pumps, till Jo said, trying to be polite and easy, “I think I’ve had the pleasure of seeing you before.
- v2: none

### S185

> I won't go before seventeen, anyway."

- Release ❌ *won’t go before seventeen, anyway* → S28: “You must have gloves, or I won’t go,” cried Meg decidedly.
- v2: none

### S189

> "How I **wish I was going to college**!

- Release ✅ *wish I was going to college* → S180: “I suppose you are going to college soon?
- v2 ✅ *wish I was going to college* → S180: "I suppose you are going to college soon?

### S204

> "Well, I have a bad trick of standing before the fire, and so I burn my frocks, and I scorched this one, and though it's nicely mended, it shows, and **Meg** told me to keep still so no one would see it.

- Release ❌ *Meg* → S?: sighed Meg.
- v2: none

### S209

> I'll tell you how we can manage.

- Release ✅ *I’ll tell you how we can manage* → S41: I’ll tell you how we can manage, each wear one good one and carry a bad one.
- v2: none

### S213

> The hall was empty, and they had a grand polka, for Laurie danced well, and taught her the German step, which delighted Jo, **being full of swing and spring**.

- Release ❌ *being full of swing and spring* → S?: answered Jo with her mouth full.
- v2: none

### S214

> When the music stopped, they **sat down on the stairs to get their breath**, and Laurie was in the midst of an account of a students' festival at Heidelberg when Meg appeared in search of her sister.

- Release: none
- v2 ❌ *sat down on the stairs to get their breath* → S3: cried Meg at the foot of the garret stairs.

### S218

> It aches so, I can hardly stand, and I don't know how I'm ever going to get home," she said, **rocking to and fro in pain**.

- Release ✅ *rocking to and fro in pain* → S116: Meg was asked at once, and the tight slippers tripped about so briskly that none would have guessed the pain their wearer suffered smilingly.
- v2: none

### S221

> But I don't see what you can do, except get a carriage, or stay here all night," answered Jo, softly **rubbing the poor ankle as she spoke**.

- Release: none
- v2 ✅ *rubbing the poor ankle as she spoke* → S216: "I've sprained my ankle.

### S229

> **I'll rest till **Hannah** comes**, and then do the best I can."

- Release ✅ *Hannah* → S89: “Don’t eat much supper, and come away at eleven when I send Hannah for you.”
- v2 ✅ *I'll rest till Hannah comes* → S89: "Don't eat much supper, and come away at eleven when I send Hannah for you."

### S230

> "**I'll ask Laurie**.

- Release ❌ *I’ll ask Laurie* → S147: asked Laurie, looking as if he thought the name suited her.
- v2 ❌ *I'll ask Laurie* → S147: asked Laurie, looking as if he thought the name suited her.

### S235

> I can't dance anymore, but as soon as supper is over, **watch for Hannah** and tell me the minute she comes."

- Release ❌ *can’t dance anymore* → S30: You can’t dance without them, and if you don’t I should be so mortified.”
- v2 ✅ *watch for Hannah* → S229: I'll rest till Hannah comes, and then do the best I can."

### S237

> I'll stay with you.

- Release ❌ *I’ll stay with you* → S31: “Then I’ll stay still.
- v2: none

### S241

> So Meg reclined, with rubbers well hidden, and Jo went blundering away to the dining room, which she found after going into a china closet, and **opening the door of a room where old Mr. Gardiner was taking a little private refreshment**.

- Release: none
- v2 ❌ *opening the door of a room where old Mr. Gardiner was taking a little private refreshment* → S98: said Meg, as she turned from the glass in Mrs. Gardiner's dressing room after a prolonged prink.

### S242

> Making a dart at the table, she secured the coffee, which she immediately spilled, thereby **making the front of her dress as bad as the back**.

- Release ❌ *making the front of her dress as bad as the back* → S97: And does my hair look very bad?”
- v2: none

### S246

> **said a friendly voice**.

- Release ❌ *said a friendly voice* → S90: As the gate clashed behind them, a voice cried from a window...
- v2: none

### S248

> "I was trying to get something for Meg, **who is very tired**, and someone shook me, and here I am in a nice state," answered Jo, glancing dismally from the stained skirt to the coffee-colored glove.

- Release ✅ *who is very tired* → S240: I’m so tired I can’t stir.”
- v2: none

### S250

> I **was looking for someone to give this to**.

- Release ❌ *was looking for someone to give this to* → S147: asked Laurie, looking as if he thought the name suited her.
- v2: none

### S254

> I don't offer to take it myself, for I **should only get into another scrape if I did**."

- Release ✅ *should only get into another scrape if I did* → S52: I’ll be as prim as I can and not get into any scrapes, if I can help it.
- v2 ✅ *should only get into another scrape if I did* → S52: I'll be as prim as I can and not get into any scrapes, if I can help it.

### S256

> They had a merry time over the bonbons and mottoes, and **were in the midst of a quiet game of Buzz, with two** or three other young people who had strayed in, when Hannah appeared.

- Release: none
- v2 ❌ *were in the midst of a quiet game of Buzz, with two* → S214: When the music stopped, they sat down on the stairs to get their breath, and Laurie was in the midst of an account of a students' festival at Heidelberg when Meg appeared in search of her sister.

### S260

> I turned my foot a little, that's all," and limped upstairs to **put her things on**.

- Release 🟡 *put her things on* → S234: Get me my rubbers, and put these slippers with our things.
- v2: none

### S262

> Slipping out, she ran down and, finding a servant, **asked if he could get her a carriage**.

- Release: none
- v2 ✅ *asked if he could get her a carriage* → S222: "I can't have a carriage without its costing ever so much.

### S263

> It happened to be a hired waiter who knew nothing about the neighborhood and Jo was looking round for help when Laurie, who had heard what she said, came up and offered his grandfather's carriage, **which had just come for him**, he said.

- Release ❌ *which had just come for him* → S?: Please come.”
- v2: none

### S265

> You can't mean to go yet?"

- Release ❌ *can’t mean to go yet* → S?: “I can’t, for I told Meg I wouldn’t, because...”
- v2: none

### S275

> asked Jo, **rumpling up her hair**, and making herself comfortable.

- Release ❌ *rumpling up her hair* → S?: My hair, oh, my hair!”
- v2: none

### S277

> Sallie's friend, Annie Moffat, took a fancy to me, and asked me to come and **spend a week with her when Sallie does**.

- Release: none
- v2 ✅ *spend a week with her when Sallie does* → S228: Sallie has some girls staying with her.

### S290

> "**Tell about the party**!

- Release ❌ *Tell about the party* → S270: That settled it, and telling him of Meg’s mishap, Jo gratefully accepted and rushed up to bring down the rest of the party.
- v2: none

### S292

> With what Meg called 'a great want of manners' Jo **had saved some bonbons for the little girls**, and they soon subsided, after hearing the most thrilling events of the evening.

- Release: none
- v2 ✅ *had saved some bonbons for the little girls* → S256: They had a merry time over the bonbons and mottoes, and were in the midst of a quiet game of Buzz, with two or three other young people who had strayed in, when Hannah appeared.

### S294

> "I don't believe fine young ladies enjoy themselves a bit more than we do, in spite of our burned hair, old gowns, one glove apiece and tight slippers that **sprain our ankles when we are silly enough to wear them**."

- Release ✅ *sprain our ankles when we are silly enough to wear them* → S216: “I’ve sprained my ankle.
- v2 ✅ *sprain our ankles when we are silly enough to wear them* → S216: "I've sprained my ankle.
