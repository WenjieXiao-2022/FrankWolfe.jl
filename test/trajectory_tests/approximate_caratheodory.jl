using FrankWolfe
using Test
using LinearAlgebra

@testset "Approximate Caratheodory" begin
    n = Int(1e2)
    k = n
    f(x) = dot(x, x)
    function grad!(storage, x)
        @. storage = 2 * x
    end
    lmo = FrankWolfe.ProbabilitySimplexOracle{Rational{BigInt}}(1)
    x0 = FrankWolfe.compute_extreme_point(lmo, zeros(n))
    res1 = FrankWolfe.frank_wolfe(
        f,
        grad!,
        lmo,
        x0,
        max_iteration=k,
        line_search=FrankWolfe.Agnostic(),
        print_iter=k / 10,
        verbose=false,
        memory_mode=FrankWolfe.OutplaceEmphasis(),
        trajectory=true,
    )
    x_true = [
        0.0003882741215298000420906058020008131649408310609791293789170887356180438746488335,
        0.01980198019801980174204644541789292442808870460109720167417109952972281608614392,
        0.0005824111822947000954662239221379876968608268608067998030881882653408599607928077,
        0.0007765482430596001991334434942656928089513067592163031453228607158571840579260239,
        0.0009706853038245001142071576214289134799237722821789055237774017039680826787031422,
        0.001164822364589400111184336970405283587112639773765304875456557608308253871966003,
        0.001358959425354300205152461976791955089903124178924704383577732186271746843393673,
        0.001553096486119200123613161507864747469883195782712153608246462591276847641400415,
        0.001747233546884100357294434425521019957092786851921236172277015496813510946277349,
        0.001941370607649000355084148151697916605542320405471402241189730786877249702816797,
        0.002135507668413900189066931434248524727347073349191061808421826725016298033411679,
        0.002329644729178800488410312568010179561296432106402094015372436636547190870300332,
        0.002523781789943700225565434613449155479169439923525110640264880421825234405418941,
        0.002717918850708600350269848067771177013721412922862882874142871429918104894240619,
        0.00291205591147350041570201695367579159623787972254067984203230754762306055249153,
        0.003106192972238400394560786197225285036706905836085303605037534758293128693317118,
        0.003300330033003300258916355706332062721509041503956562888727843249850295719733871,
        0.003494467093768200251325330593196232310842990450393933524221947330680444464801797,
        0.003688604154533100697556137630165387507087463584696562039873803199973987540303863,
        0.003882741215298000280510808464921223759615693413602755056045890689674985547160767,
        0.00407687827606290064532026901580120486067843846746828308661372200214047850445762,
        0.004271015336827800427670876015566418686819475875595140831696815232904816981848156,
        0.004465152397592700300644336281093783497378622647194256618042782330258695147220924,
        0.004659289458357600677783291847942320143740766052565949841229649920963748897450388,
        0.004853426519122500896862928565677777041960696594773910546541017125149389768231225,
        0.005047563579887400349929630024666106085486734275760558106092747026142268542084198,
        0.005241700640652300341005936027750888413411734405841787912836956874284273716155194,
        0.00543583770141720057436003632732971030264900193553537983270382110156803150697447,
        0.005629974762182100589292066545240496295677412189293474973894895544004801637854435,
        0.005824111822947000517638310026842471159962562890845771609185545744710134470069804,
        0.006018248883711900701932882326610513372895371860262337947266895500772264370506452,
        0.006212385944476800908128635903858300909265914693511109145245709075835008967892594,
        0.00640652300524170066422578228968641770665207338003948639873636061394374866678618,
        0.006600660066006600557359378411173783772985854572743890592194880849228212329337688,
        0.006794797126771500386545512812456811572419257253162939345016658340655232305565304,
        0.006988934187536401195686594588074609470046050625234469822884195336852657125810076,
        0.007183071248301300409266749345183476159104719175745343710122816828861705300913898,
        0.007377208309066200560061965330916936616011159980384306485951899215672861836708123,
        0.007571345369831101279899089099088304922555625123844674161593767025998054468133567,
        0.007765482430596001164881812390191680924328763077692843290633454302067358885193008,
        0.007959619491360900453909058475207330562637289289433195582248086795503407199549887,
        0.008153756552125800798928511006417766098936651650480496399871402018830343330168034,
        0.008347893612890701176534868560091450195396973866365810906807885915571452626113312,
        0.008542030673655601307967178640919486153647539009220933851635363471482090487691809,
        0.00873616773442050075078826721717919899202251630021742963554249833846591305019406,
        0.008930304795185400788816446073157731797754066857474622838211076501534872729621664,
        0.009124441855950300499031628042345539294270742940546650118460350669628920497759703,
        0.009318578916715200251694679550134014468299418906561575450695397869751669122905964,
        0.009512715977480101222301324703840348642382550557410309832498657210498216952646775,
        0.009706853038245000904973779903363673581004979002947935413756836518327343874430699,
        0.0099009900990099016320770682571002291766549020792077889481789544538601141709446,
        0.01009512715977480070330824787906891629563373076946674992991200547443165470943348,
        0.01028926422053970051637508985296103104660194327194007132380297848464365888908827,
        0.01048340128130460057964603797243673491034795241123139853761533363574100564529313,
        0.01067753834206950049433723497680551125679768720723401690218629975107771825032686,
        0.01087167540283440048137975861551520190308648645415513892201368413746230465165757,
        0.01106581246359930094519821056024475725539512769931169270997742942154266365415643,
        0.0112599495243642010776072982374634441426459478403852462389394401015731387373364,
        0.01145408658512910097148740796889579104395205691141874912211224599265740517284452,
        0.01164822364589400177634721185875880307334706151764883596750916727135335832714923,
        0.01184236070665890085000844219501227066229223105968599835591091296187120571031923,
        0.01203649776742380050795620263230436802814918235516324391622967535376103153864806,
        0.01223063482818870119508566421211684305164362598722788261331502425648517932718499,
        0.01242477188895360192566433248854698343239195924888124543133065605136144662402779,
        0.01261890894971850161645291494117749275706921765669271800234889834719208741784181,
        0.01281304601048340103366692941290102843591929193787306581993324382956797460467683,
        0.01300718307124830111155011896558288170400676047079890947090334808860479446565325,
        0.0132013201320132014764352267990904589902516307904252174466644298270810754193482,
        0.01339545719277810090490999756557855998351794416471997932888884896144015361937024,
        0.01358959425354300165770749624107258273621732815857823972553851445204449384523709,
        0.01378373131430790058353427727134755693341739798151426914212557635497450527288925,
        0.01397786837507280056989595539462618913710466709102404872348580950795279206680487,
        0.01417200543583770217307274924529067217964816864079098545083758936335685302700349,
        0.01436614249660260235270996444740609603744037097610924457965873509741432887767511,
        0.01456027955736750061985247998325491756704232592649562644968080288920001566116641,
        0.01475441661813240244569157876376825183183079469330507518766274847124142133175206,
        0.01494855367889730096019031098249851356565128185557548309989320843792554392292997,
        0.01514269073966220125547184677174924561603050296439632178532462686450923065046429,
        0.01533682780042710238420887516800915735472049531756248279604816939853819969912974,
        0.01553096486119200066827888284966917628380692198382831995136190350118819394452864,
        0.0157251019219569021087643008579889656067583836404881456889707058514564626115519,
        0.01591923898272180243140911317995190618158270529328470342331381641626380482146769,
        0.01611337604348670070620444686537384592071367002483289832602471899478622134821486,
        0.01630751310425160138819624759733579805501498450009937461693400873057554799529194,
        0.01650165016501650139926986008137823799559838250160816524032817173921091857383403,
        0.01669578722578140141028007979048119408425319324677463861957170414247959742750423,
        0.01688992428654630214076512442467616982886122586518095906913109519577109285864251,
        0.01708406134731120120611506433379078225892196616485648363362907091079387525566909,
        0.01727819840807610237377742877896019445606740817927518800647707479448108625659192,
        0.01747233546884100312822173580837901199072761007053886286328615959502762658879238,
        0.01766647252960590128265011872399721132014544232993445792944682128778320059295789,
        0.0178606095903708032490284312604307728446385580457409920995885098087747905279215,
        0.01805474665113570139561221383225131733707823572401386027164683146405154870468538,
        0.01824888371190060143342528481993271072179130589404018055997421790869707617200101,
        0.01844302077266550081901437253928410048000392634317940606703856904328115317566703,
        0.01863715783343040149908517569608539728431614317130150542900034863564971816073049,
        0.01883129489419530034004655890248654653852444965838982238279157704916206502274489,
        0.01902543195496020351226333102072831389732383717536576363318028356443370391048994,
        0.01921956901572510232266421678436112468933955605034956800251944650364831594880664,
        0.01941370607649000218250087532506190641350721586961201686937898271255334512602753,
    ]
    primal_true = 0.01314422099649411305714214236596045839642713180124049726321024688069930261252318
    @test norm(res1[1] - x_true) ≈ 0 atol = 1e-6
    @test res1[3] ≈ primal_true
    @test res1[5][end][1] == 101

    res2 = FrankWolfe.frank_wolfe(
        f,
        grad!,
        lmo,
        x0,
        max_iteration=k,
        line_search=FrankWolfe.Shortstep(2 // 1),
        print_iter=k / 10,
        verbose=false,
        memory_mode=FrankWolfe.OutplaceEmphasis(),
        trajectory=true,
    )
    x_true = fill(0.01, n)
    primal_true = 0.01
    @test norm(res2[1] - x_true) ≈ 0 atol = 1e-6
    @test res2[3] ≈ primal_true
    @test res2[5][end][1] == 100

    res3 = FrankWolfe.away_frank_wolfe(
        f,
        grad!,
        lmo,
        x0,
        max_iteration=k,
        line_search=FrankWolfe.Agnostic(),
        print_iter=k / 10,
        verbose=false,
        memory_mode=FrankWolfe.OutplaceEmphasis(),
        trajectory=true,
    )

    x_true = [
        0.01941747572815534389500426171171199030140996910631656646728515625,
        0.0197982105463544663941262424788902762884390540421009063720703125,
        0.000571102227298686689581364017698206225759349763393402099609375,
        0.000761469636398249606103194597750416505732573568820953369140625,
        0.0009518370454978121973643734321512965834699571132659912109375,
        0.00114220445459737337916272803539641245151869952678680419921875,
        0.00133257186369693564516325512414596232702024281024932861328125,
        0.00152293927279649921220638919550083301146514713764190673828125,
        0.00171330668189606061084517829584683568100444972515106201171875,
        0.001903674090995624394728746864302593166939914226531982421875,
        0.00209404150009518362496319099363972782157361507415771484375,
        0.0022844089091947467583254560707928249030373990535736083984375,
        0.0024747763182943077232833761769370539695955812931060791015625,
        0.0026651437273938712903265102482919246540404856204986572265625,
        0.00285551113649343442368877532544502173550426959991455078125,
        0.003045878545592995388646695431589250802062451839447021484375,
        0.003236245954692557220966353526137027074582874774932861328125,
        0.00342661336379211818592427363228125614114105701446533203125,
        0.0036169807728916821866482766978379004285670816898345947265625,
        0.0038073481819912470547340177517980919219553470611572265625,
        0.003997715591090806284968461881135226576589047908782958984375,
        0.0041880830001903672499263819872794556431472301483154296875,
        0.004378450409289933419054730023844967945478856563568115234375,
        0.004568817818389493516650912141585649806074798107147216796875,
        0.004759185227489053614247094259326331666670739650726318359375,
        0.004949552636588615446566752353874107939191162586212158203125,
        0.00513992004568817988097162441363252582959830760955810546875,
        0.005330287454787742580653020496583849308080971240997314453125,
        0.005520654863887302678249202614324531168676912784576416015625,
        0.0057110222729868688473775506508900434710085391998291015625,
        0.005901389682086429812335470757034272537566721439361572265625,
        0.00609175709118599077729339086317850160412490367889404296875,
        0.006282124500285551742251310969322730670683085918426513671875,
        0.006472491909385111839847493087063412531279027462005615234375,
        0.006662859318484675406890627158418283215723931789398193359375,
        0.0068532267275842363718485472645625122822821140289306640625,
        0.007043594136683799071529943347513835760764777660369873046875,
        0.007233961545783364373296553395675800857134163379669189453125,
        0.007424328954882922736169259536609388305805623531341552734375,
        0.007614696363982494109468035503596183843910694122314453125,
        0.00780506377308205247234074164452977129258215427398681640625,
        0.0079954311821816108352134477854633587412536144256591796875,
        0.00818579859128116919808615392639694618992507457733154296875,
        0.0083761660003807310304058120209447224624454975128173828125,
        0.00856653340948029286272547011549249873496592044830322265625,
        0.00875690081857986336866250809407574706710875034332275390625,
        0.0089472682276794286704291181422377121634781360626220703125,
        0.00913763563677898182913139635275001637637615203857421875,
        0.00932800304587855060034495835452617029659450054168701171875,
        0.00951837045497810375904723656503847450949251651763916015625,
        0.009708737864077665591366894659586250782012939453125,
        0.00989910527317723089313350470774821587838232517242431640625,
        0.01008947268227679446017663877910308656282722949981689453125,
        0.0102798400913763528230493449200366740114986896514892578125,
        0.0104702075004759198595394309450057335197925567626953125,
        0.01066057490957548169185908903955350979231297969818115234375,
        0.01085094231867504525890222311090838047675788402557373046875,
        0.01104130972777460535649840522864906233735382556915283203125,
        0.01123167713687416545409458734638974419794976711273193359375,
        0.01142204454597373075586119739455170929431915283203125,
        0.01161241195507328911873390353548529674299061298370361328125,
        0.01180277936417285962467094151406854507513344287872314453125,
        0.0119931467732724179875436476550021325238049030303955078125,
        0.01218351418237198328931025770316409762017428874969482421875,
        0.0123738815914715451216299157977118738926947116851806640625,
        0.01256424900057110695394957389225965016521513462066650390625,
        0.01275461640967066011265185210277195437811315059661865234375,
        0.0129449838187702288838654141045481082983314990997314453125,
        0.01313535122786978724673812024548169574700295925140380859375,
        0.01332571863696935081378125431683656643144786357879638671875,
        0.01351608604606891438082438838819143711589276790618896484375,
        0.0137064534551684762131440464827392133884131908416748046875,
        0.0138968208642680328412932766468657064251601696014404296875,
        0.01408718827336760161250683864864186034537851810455322265625,
        0.0142775556824671530364856408823470701463520526885986328125,
        0.01446792309156672180769920288412322406657040119171142578125,
        0.01465829050066628537474233695547809475101530551910400390625,
        0.0148486579097658437376150430964116821996867656707763671875,
        0.01503902531886540903938165314457364729605615139007568359375,
        0.01522939272796497954531869112315689562819898128509521484375,
        0.015419760137064530969297493356862105429172515869140625,
        0.01561012754616410147523453133544535376131534576416015625,
        0.0158004949552636615728307134531860356219112873077392578125,
        0.0159908623643632182009799436173125286586582660675048828125,
        0.0161812297734627817680230776886673993431031703948974609375,
        0.0163715971825623453350662117600222700275480747222900390625,
        0.016561964591661905432662393877762951888144016265869140625,
        0.016752332000761462060811624041889444924890995025634765625,
        0.016942699409861032566748662020472693257033824920654296875,
        0.0171330668189605926643448441382133751176297664642333984375,
        0.0173234342280601527619410262559540569782257080078125,
        0.01751380163715972326787806423453730531036853790283203125,
        0.01770416904625927989602729439866379834711551666259765625,
        0.017894536455358843463070428470018669031560420989990234375,
        0.0180849038644584035606666105877593508921563625335693359375,
        0.0182752712735579671277097446591142215766012668609619140625,
        0.018465638682657527225305926776854903437197208404541015625,
        0.018656006091757097731242964755438151769340038299560546875,
        0.018846373500856654359392194919564644806087017059326171875,
        0.01903674090995621792643532899091951549053192138671875,
    ]

    primal_true = 0.01303054586957625556729890004358024648004703487744009407127266414409524716045483

    @test norm(res3[1] - x_true) ≈ 0 atol = 1e-6
    @test res3[3] ≈ primal_true
    @test res3[5][end][1] == 101

    res4 = FrankWolfe.blended_conditional_gradient(
        f,
        grad!,
        lmo,
        x0,
        max_iteration=k,
        line_search=FrankWolfe.Adaptive(),
        print_iter=k / 10,
        verbose=false,
        memory_mode=FrankWolfe.OutplaceEmphasis(),
        trajectory=true,
    )

    x_true = [
        0.0108027126845414052358496093120265868492424488067626953125,
        0.0108031676887078986748491615799139253795146942138671875,
        0.010803796447492110266441756039057509042322635650634765625,
        0.01080238849816639486178804219207449932582676410675048828125,
        0.0108025092403021931442008707335844519548118114471435546875,
        0.0108061507083951867380644529248456819914281368255615234375,
        0.0108045738178759002934281596708387951366603374481201171875,
        0.0108026045046730294341141842551223817281424999237060546875,
        0.01080011563850667537234340187524139764718711376190185546875,
        0.01080985754913697804990846407235949300229549407958984375,
        0.0108087867495978741383400034692385816015303134918212890625,
        0.01080756230830257243191727667408486013300716876983642578125,
        0.01080614567974684352147374255537215503863990306854248046875,
        0.0108044852622646118944782500648216228000819683074951171875,
        0.0108025105805995107199901639205563697032630443572998046875,
        0.0108001231331857662498752148394487448967993259429931640625,
        0.01080965555558705860905721607423402019776403903961181640625,
        0.01080848772595357186465658827501101768575608730316162109375,
        0.0108071652204830177812500124900907394476234912872314453125,
        0.010805653148583650724479099380914703942835330963134765625,
        0.01080929718533599724616944826038889004848897457122802734375,
        0.01082712155810004739375784765798016451299190521240234375,
        0.010789842638755216264190295305525069124996662139892578125,
        0.0107729066226187504551337070779482019133865833282470703125,
        0.0107851181110980194610693416734648053534328937530517578125,
        0.01079902457728214304477631912959623150527477264404296875,
        0.01081501867416376390373944360590030555613338947296142578125,
        0.01083363067466580446918111846343890647403895854949951171875,
        0.01075507863963345682456473895172166521660983562469482421875,
        0.01076519649089746448467064254828073899261653423309326171875,
        0.01077654232978828875710863854919807636179029941558837890625,
        0.0107893432803173212886083121020419639535248279571533203125,
        0.010803894279972074687901084644181537441909313201904296875,
        0.01082058470026692718890526379027505754493176937103271484375,
        0.0108399377983205806585953467902072588913142681121826171875,
        0.0107589051789772037481807132053290843032300472259521484375,
        0.01076957147599914323132797022708473377861082553863525390625,
        0.0107815348147476848528203419164128717966377735137939453125,
        0.01079502917090472378924825846979729249142110347747802734375,
        0.0108103569813084894601917795853296411223709583282470703125,
        0.01082791592023595560190241116060860804282128810882568359375,
        0.0107521978822832618705174212436759262345731258392333984375,
        0.01076215436950768607193840153968267259187996387481689453125,
        0.010773278282806657280001871868080343119800090789794921875,
        0.01078576035840632385554016536843846552073955535888671875,
        0.01079984229476984268492056884269914007745683193206787109375,
        0.01081583556698076202529090750203977222554385662078857421875,
        0.0108341486769648366605967026998769142664968967437744140625,
        0.010755845374480037246467389877579989843070507049560546875,
        0.010766274605739901970569150080336839891970157623291015625,
        0.01077793470879333422030033062810616684146225452423095703125,
        0.01079102578246056431954258414407377131283283233642578125,
        0.0108058008592045486084831651396598317660391330718994140625,
        0.0108225854349977522461667689412934123538434505462646484375,
        0.01074939544467318035259051356433701585046947002410888671875,
        0.01075912756914160044174888497536812792532145977020263671875,
        0.0107699805137499715623761176175321452319622039794921875,
        0.010782123014237733615861003499958314932882785797119140625,
        0.01079576471961148607936475940505260950885713100433349609375,
        0.01081117049212004972702505511961135198362171649932861328125,
        0.01082868080762208577716432245097166742198169231414794921875,
        0.010752902405041085687198432196964859031140804290771484375,
        0.01076306644517314829723186875298779341392219066619873046875,
        0.010774409367257063718792409190427861176431179046630859375,
        0.01078710938565098122199348296135212876833975315093994140625,
        0.0108013878765403810444656329536883276887238025665283203125,
        0.010817524491474876657814974123539286665618419647216796875,
        0.01074668445017604688496160036947912885807454586029052734375,
        0.0107561705420754459561205607087686075828969478607177734375,
        0.0107667373015882632258932716240451554767787456512451171875,
        0.01077853831119834383811539879616248072125017642974853515625,
        0.01079176140365109386187736362217037822119891643524169921875,
        0.0108066400314156541018206780790933407843112945556640625,
        0.01082346930300583966177985217882451252080500125885009765625,
        0.010750071741246584877682579417523811571300029754638671875,
        0.01075996275640538589468686581085421494208276271820068359375,
        0.0107709881091119612228634849770969594828784465789794921875,
        0.01078331037176055891280146425970087875612080097198486328125,
        0.01079712857197169008360848607708248891867697238922119140625,
        0.0108126903473306605618642350918889860622584819793701171875,
        0.0104974492752743266132942068225020193494856357574462890625,
        0.01116460114424191497894955915626269415952265262603759765625,
        0.00824936385247393259845249957606938551180064678192138671875,
        0.00915567683228720417820678534326361841522157192230224609375,
        0.01016915943841223586574518122915833373554050922393798828125,
        0.01130629453096848070769997463003164739347994327545166015625,
        0.0125875810923902660409812170883014914579689502716064453125,
        0.0097127302203648992195983424835503683425486087799072265625,
        0.00860806048487504360533506542196846567094326019287109375,
        0.009557005178213805185460927305030054412782192230224609375,
        0.01061905364543977957347831164724993868730962276458740234375,
        0.01181184859334383219220399041660130023956298828125,
        0.0131573924955964045857559341357045923359692096710205078125,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
    ]

    primal_true = 0.01077995686715228612254753440787718170115164892554758528956542479479657845736762

    @test norm(res4[1] - x_true) ≈ 0 atol = 1e-6
    @test res4[3] ≈ primal_true
    @test res4[5][end][1] == 101



end

@testset "Approximate Caratheodory with random initialization" begin
    rhs = 1
    k = 1e5
    x_true = [
        61512951376323730454002197150348389314089326897787615721998692413353959632437 //
        3705346855594118253554271520278013051304639509300498049262642688253220148477952,
        7278301191941549131183323094243942700957644187929251522094354780914218275643 //
        7410693711188236507108543040556026102609279018600996098525285376506440296955904,
        8366562124555104321121369841697389597845181508166497753247502851926662059563 //
        231584178474632390847141970017375815706539969331281128078915168015826259279872,
        85023391065000333202828293111143357401972379805025875286177370028514589002563 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        65161147193679930666908924856262469104197138809185702944157386640936864997051 //
        3705346855594118253554271520278013051304639509300498049262642688253220148477952,
        79601478169795915975697070307050727165420854919928218988885008389058048219799 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        67837373726039687662074349377195592477915195880054271380448921303995127196787 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        55169871312251590938351075012017608231499182261935245722772561815939463686945 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        86815771044534708965244863268893818174646630872044525249352735709981389751563 //
        29642774844752946028434172162224104410437116074403984394101141506025761187823616,
        72336771117105959301574221890003216380657564844338588751171518976178113048017 //
        29642774844752946028434172162224104410437116074403984394101141506025761187823616,
        19890931658710480666057076719356895452123545713808612893617662915732470931561 //
        3705346855594118253554271520278013051304639509300498049262642688253220148477952,
        79585978057301384008717145909924897970180606286778393928727017924984613374659 //
        3705346855594118253554271520278013051304639509300498049262642688253220148477952,
        113965904146211811471977184949419222372334011462703157205004739574650127142033 //
        3705346855594118253554271520278013051304639509300498049262642688253220148477952,
        5428354262203226529922598481638522646897396408804020092482524536075502397089 //
        926336713898529563388567880069503262826159877325124512315660672063305037119488,
        34827625827775960484301801523292094477572109942336300722774749588002270047107 //
        926336713898529563388567880069503262826159877325124512315660672063305037119488,
        8144733136987354412249131885422478920455820770248694226860937021089948464221 //
        926336713898529563388567880069503262826159877325124512315660672063305037119488,
        83223495385376576134214902972508569795914027222867150904993148656647549582643 //
        3705346855594118253554271520278013051304639509300498049262642688253220148477952,
        54297750348315411085069411691276033515094776339188270147174153874826550949759 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        37999445234583642959973667475688948272912144623017138000156880088920795412827 //
        926336713898529563388567880069503262826159877325124512315660672063305037119488,
        79609315854867434707411488589752461150308986825456950218827676254431104225223 //
        14821387422376473014217086081112052205218558037201992197050570753012880593911808,
        36228520792880844351408349957314092789406418697994688604833502039464381047593 //
        3705346855594118253554271520278013051304639509300498049262642688253220148477952,
        87747074626700853575232381986258310602806824140384221969315398151119893566027 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        14247237619794261330995555194505323439550547179850901735114007176618394961353 //
        463168356949264781694283940034751631413079938662562256157830336031652518559744,
        14248684606965137684515955910711963166771474351946426521187714925472414576673 //
        463168356949264781694283940034751631413079938662562256157830336031652518559744,
        84150822879115430935288141198806087582607671818743223481767144916744174202711 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        80512422222849887485621734147521502765322572979265885473937061004907501946415 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        13575133430342896240925710532529889229904841799812827659124544788029451500505 //
        926336713898529563388567880069503262826159877325124512315660672063305037119488,
        85930842192362005344537760883863364225750024310074067572323399741581216569741 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        65021782163379251030074430456678178405938486301538530120830779975596245752847 //
        14821387422376473014217086081112052205218558037201992197050570753012880593911808,
        40701251232106608633770622134695258535560875020915747471858891813546395472325 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        39798030372341094444100232335522337649867082740716224935897408719862574204305 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        84121644147995396625591066877556253744715337783486488304563392406881190793051 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        33922055663316267391672695885159354882451875454551025177383028349114163057371 //
        926336713898529563388567880069503262826159877325124512315660672063305037119488,
        15831205501799787359855727259669406012682835451292628159505016130571475753067 //
        463168356949264781694283940034751631413079938662562256157830336031652518559744,
        97667231102575253732993923620041238774510608407541976676513500282167400753847 //
        7410693711188236507108543040556026102609279018600996098525285376506440296955904,
        61506200807405941080369582838580555432120089840841225703478555148085366801593 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        69663077113345636859399373513055005486354570697173148668421658523479885425043 //
        1852673427797059126777135760139006525652319754650249024631321344126610074238976,
        101464980607353895107673290372367186084458336535036844511537017865818241482095 //
        29642774844752946028434172162224104410437116074403984394101141506025761187823616,
        30762334036323628501430433726571171454828575613210821709890893791022869772097 //
        3705346855594118253554271520278013051304639509300498049262642688253220148477952,
        29403498868980333524589803906472036743111538604830514310901745746061273020257 //
        926336713898529563388567880069503262826159877325124512315660672063305037119488,
    ]
    primal_true =
        9.827847816235913956551323164596263945321701473649212104977642156975401442102586e-10
    xp = [
        17 // 1024,
        1 // 1024,
        37 // 1024,
        47 // 1024,
        9 // 512,
        11 // 256,
        75 // 2048,
        61 // 2048,
        3 // 1024,
        5 // 2048,
        11 // 2048,
        11 // 512,
        63 // 2048,
        3 // 512,
        77 // 2048,
        9 // 1024,
        23 // 1024,
        15 // 512,
        21 // 512,
        11 // 2048,
        5 // 512,
        97 // 2048,
        63 // 2048,
        63 // 2048,
        93 // 2048,
        89 // 2048,
        15 // 1024,
        95 // 2048,
        9 // 2048,
        45 // 2048,
        11 // 512,
        93 // 2048,
        75 // 2048,
        35 // 1024,
        27 // 2048,
        17 // 512,
        77 // 2048,
        7 // 2048,
        17 // 2048,
        65 // 2048,
    ]
    direction = [
        0.00928107242432663,
        0.3194042202333671,
        0.7613490224961625,
        0.9331502775657023,
        0.5058966756232495,
        0.7718148164937879,
        0.3923111977240855,
        0.12491790837874406,
        0.8485975494086246,
        0.453457809041527,
        0.43297176382458114,
        0.6629759429794072,
        0.8986003842140354,
        0.6074039179253773,
        0.9114822007027404,
        0.04278632498941526,
        0.352674631558033,
        0.7886492242572878,
        0.7952842710030733,
        0.7874206770511923,
        0.7726147629233262,
        0.6012149427173692,
        0.13299869717521284,
        0.49058432205062985,
        0.57373575784723,
        0.9237295811565405,
        0.13315214983763268,
        0.3558682954823691,
        0.8655648010180531,
        0.2246697359783949,
        0.5047341378190603,
        0.34094108472913265,
        0.11227329675627062,
        0.27474436461569807,
        0.1803131027661613,
        0.5219938641083894,
        0.6233658038612543,
        0.2217260674856315,
        0.5254499622424393,
        0.14597502257203032,
    ]

    f(x) = norm(x - xp)^2
    function grad!(storage, x)
        @. storage = 2 * (x - xp)
    end

    lmo = FrankWolfe.ProbabilitySimplexOracle{Rational{BigInt}}(rhs)
    x0 = FrankWolfe.compute_extreme_point(lmo, direction)

    res5 = FrankWolfe.frank_wolfe(
        f,
        grad!,
        lmo,
        x0,
        max_iteration=k,
        line_search=FrankWolfe.Agnostic(),
        print_iter=k / 10,
        memory_mode=FrankWolfe.InplaceEmphasis(),
        verbose=false,
        trajectory=true,
    )
    @test norm(res5[1] - x_true) ≈ 0 atol = 1e-6
    @test res5[3] ≈ primal_true
    @test res5[5][end][1] == 100001
end