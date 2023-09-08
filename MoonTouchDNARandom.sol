// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./SecurityBase.sol";
import "./IGenerator.sol";

contract MoonTouchDNARandom is IGenerator, SecurityBase {

    event DNAEvent(string DNA);

    uint256 private GeneScope = 9;
	uint256[] private ImageWeight = [18000,18000,7200,20000,4800,3600,20000,20000,7200];

	uint256[] private ImageReward = [1,2,4,5,6,7,8,9,10];

	uint private ImageWeightSum = 118800;

	uint256[] private CampByImage= [2,1,3,1,2,2,3,4,4];

	uint256[] private QualityByImage = [4,4,3,5,2,1,5,5,3];

    uint256[] private SpeedByImage = [2,3,1,2,1,6,1,3,2];
    
	uint256[][] private AttributeByQuality = [
        [uint(40),uint(4),uint(12)],
        [uint(60),uint(6),uint(18)],
        [uint(120),uint(12),uint(36)],
        [uint(240),uint(24),uint(72)],
		[uint(480),uint(48),uint(144)]	
	];

	uint256[][] private AttributeWeightByCamp = [
		[uint(0),uint(0),uint(3333),uint(3333),uint(3334)],
		[uint(55),uint(27),uint(5),uint(5),uint(556)],
		[uint(714),uint(714),uint(714),uint(714),uint(7144)],
		[uint(2000),uint(2000),uint(2000),uint(2000),uint(2000)]
	];

	uint256[] private AttributeWeightSumByCamp = [10000,648,10000,10000];

	uint256[][] private DurabilityRewardBySpeed = [
		[uint(200),uint(400)],
		[uint(300),uint(600)],
		[uint(400),uint(700)],
		[uint(200),uint(600)],
		[uint(300),uint(700)],
		[uint(200),uint(700)]
	];

    
    string private constant defaultBatchNo  = "A01";
    string private constant defaultLevel    = "00";
    string private constant defaultMood     = "3";
    string private constant defaultGen      = "01";
    string private constant defaultRep      = "07";
    string private constant defaultEvol     = "09";

    constructor() {}

    function rand(uint256 salt) private view returns(uint256) {
       return uint256(
           keccak256(
               abi.encodePacked(
                   salt, 
                   block.number, 
                   block.timestamp, 
                   block.coinbase
                )
            )
        );
    }

    // function random(uint256 seed ,uint256 a, uint256 b) 
    //     private 
    //     view 
    //     returns(uint256 value ,uint256 new_seed)
    // {
    //     new_seed = rand(seed);
    //     value = new_seed % a + b;
    // }

    struct DNA {
        string batch;
        uint256 image;
        string level;
        uint256 camp;
        uint256 quality;
        uint256 speed;
        string generation;
        string attribute;
        string durability;
        string mood;
        string reproduction;
        string evolutionary;
        string gene1;
        string gene2;
        uint256 seed;
    }

    function spawn(uint seed) 
        public 
        whenNotPaused
        onlyMinter
        returns(string memory)
    {
        DNA memory dna;
        dna.seed = seed;

        dna.batch = defaultBatchNo;
        dna.level = defaultLevel;
        dna.mood = defaultMood;
        dna.generation = defaultGen;
        dna.reproduction = defaultRep;
        dna.evolutionary = defaultEvol;

        getImage(dna);

        dna.camp = CampByImage[dna.image];
        dna.quality = QualityByImage[dna.image];
        dna.speed = SpeedByImage[dna.image];

        getAttribute(dna);
        getDurability(dna);
        getGene(dna);
        return encode(dna);
    }

    function encode(DNA memory dna) 
        private 
        returns(string memory date)
    {
        string memory qualitydate=getSoleAttributeDate(dna.quality,2);
        date=_stringJoin(dna.batch,getSoleAttributeDate(ImageReward[dna.image],3));
        date=_stringJoin(date,dna.level);
        date=_stringJoin(date,getSoleAttributeDate(dna.camp,2));
        date=_stringJoin(date,qualitydate);
        date=_stringJoin(date,getSoleAttributeDate(dna.speed,2));
        date=_stringJoin(date,dna.generation);
        date=_stringJoin(date,dna.attribute);
        date=_stringJoin(date,dna.durability);
        date=_stringJoin(date,dna.mood);
        date=_stringJoin(date,dna.reproduction);
        date=_stringJoin(date,dna.evolutionary);
        date=_stringJoin(date,dna.gene1);
        date=_stringJoin(date,dna.gene2);
        emit DNAEvent(date);
    }

    function getGene(DNA memory dna) 
        private 
        view
    {
        getGeneDate(dna,1);
        getGeneDate(dna,2);
    }

    function getGeneDate(DNA memory dna,uint256 typeNumber) 
        private 
        view
    {
        string memory date;
        if(typeNumber == 1){
            date =_stringJoin(getSoleAttributeDate(QualityByImage[dna.image],1),getSoleAttributeDate(ImageReward[dna.image],3));
            dna.gene1=_stringJoin("#",date);
        }else{
            date =_stringJoin(getSoleAttributeDate(QualityByImage[dna.image],1),getSoleAttributeDate(ImageReward[dna.image],3));
            dna.gene2=_stringJoin("&",date);    
        }
    }

    function getImage(DNA memory dna) 
        private 
        view 
    {
        (dna.image,dna.seed)=weightNmb(dna.seed,ImageWeight,ImageWeightSum);
    }

    function getDurability(DNA memory dna) 
        private 
        view
    {
        uint256 attributeMinNumer = DurabilityRewardBySpeed[dna.speed-1][0];
        uint256 attributeMaxNumer=DurabilityRewardBySpeed[dna.speed-1][1];
        uint256 randNumber = rand(dna.seed);
        dna.seed = randNumber;

        uint256 scope =  attributeMaxNumer-attributeMinNumer;
        uint256 rewardDate = getRandNumber(randNumber,scope);
        rewardDate = rewardDate+attributeMinNumer;
        dna.durability= _stringJoin(getSoleAttributeDate(rewardDate,3),getSoleAttributeDate(rewardDate,3));
    }

    function getAttribute(DNA memory dna) 
        private 
        view
    {
        uint256 quality=QualityByImage[dna.quality]-1;
        uint256 camp=CampByImage[dna.camp]-1;
        RandomCtx memory ctx;
        ctx.gross=AttributeWeightSumByCamp[camp];
        ctx.WeightAndRewarddate = AttributeWeightByCamp[camp];
        ctx.seed= dna.seed;
        ctx.allMax=AttributeByQuality[quality][0];
        ctx.least=AttributeByQuality[quality][1];
        ctx.soleMax=AttributeByQuality[quality][2];
        getAttributeRandom(dna,ctx);
    }

    struct RandomCtx {
        uint256 seed;
        uint256 allMax;
        uint256 least;
        uint256 soleMax;
        uint256 gross;
        uint256[] WeightAndRewarddate;
    }

    function getAttributeRandom(DNA memory dna, RandomCtx memory ctx )
        private 
        view 
    {
        uint256 stat=ctx.allMax-ctx.least*5;
        uint256 residueStat = stat;
        uint256[] memory Attribute = new uint256[](5);
        string memory date;

        uint number=getRandomAttributeNumber(ctx,stat,0,residueStat);
        residueStat = residueStat-number;
        Attribute[0]=number+ctx.least;

        number=getRandomAttributeNumber(ctx,stat,1,residueStat);
        residueStat = residueStat-number;
        Attribute[1]=number+ctx.least;
        
        number=getRandomAttributeNumber(ctx,stat,2,residueStat);
        residueStat = residueStat-number;
        Attribute[2]=number+ctx.least;
        
        number=getRandomAttributeNumber(ctx,stat,3,residueStat);
        residueStat = residueStat-number;
        Attribute[3]=number+ctx.least;
        
        number=getRandomAttributeNumber(ctx,stat,4,residueStat);
        residueStat = residueStat-number;
        Attribute[4]=number+ctx.least;
        
        allocateRemainingStar(ctx,Attribute,residueStat);

        date=_stringJoin(getSoleAttributeDate(Attribute[0],3),getSoleAttributeDate(Attribute[1],3));
        date=_stringJoin(date,getSoleAttributeDate(Attribute[2],3));
        date=_stringJoin(date,getSoleAttributeDate(Attribute[3],3)); 
        date=_stringJoin(date,getSoleAttributeDate(Attribute[4],3));
        dna.seed = ctx.seed;
        dna.attribute=date;
    }

    function allocateRemainingStar(RandomCtx memory ctx, uint256[] memory values,uint256 residueStat) 
        private 
        view
    {
        do {
            uint cnt = 0;
            for (uint i = 0; i < values.length; i++) {
                if (values[i] < ctx.soleMax) {
                    cnt++;
                }
            }
            if (residueStat >= cnt) {
                for (uint i = 0; i < values.length; i++) {
                    if (values[i] < ctx.soleMax) {
                        values[i]++;
                    }
                }
                residueStat -= cnt;
            } else {
                for (uint i = 0; i < residueStat; i++) {
                    ctx.seed = rand(ctx.seed);
                    uint index = ctx.seed % cnt + 1;
                    for (uint j = 0; j < values.length; j++) {
                        if (values[j] < ctx.soleMax ) {
                            index--;
                            if (index <= 0) {
                                values[j]++;
                                if(values[j] >= ctx.soleMax){
                                    cnt--;
                                }
                                break;
                            }
                        }
                    }
                }
                residueStat = 0;
            }
        } while(residueStat > 0);
    }    

    function getRandomAttributeNumber(RandomCtx memory ctx,uint256 stat,uint256 AttributeType,uint256 residueStat) 
        private 
        view 
        returns(uint256)
    {
        uint256 percentage;
        uint256 attributeNumer=0;
        uint256 availableTime = ctx.soleMax-ctx.least;
        if(ctx.WeightAndRewarddate[AttributeType]==0){
            return 0;
        }
        percentage=stat*ctx.WeightAndRewarddate[AttributeType];
        attributeNumer=percentage/ctx.gross;
            
        if(attributeNumer>availableTime){
            attributeNumer=availableTime;
        }
        return getAttributeNumber(ctx,attributeNumer,AttributeType,residueStat);
    }

    function getAttributeNumber(RandomCtx memory ctx,uint256 attributeNumber,uint256 AttributeType,uint256 residueStat)
        private 
        view  
        returns (uint256 rewardDate)
    {
        uint256 attributeMaxNumber = attributeNumber*12/10;
        uint256 attributeMinNumber = attributeNumber*8/10;
        uint256 randNumber = rand(ctx.seed);
        ctx.seed = randNumber;

        uint256 scope =  attributeMaxNumber-attributeMinNumber;
        rewardDate = getRandNumber(randNumber,scope);
        rewardDate = rewardDate+attributeMinNumber;  
        if(rewardDate>residueStat){
            rewardDate =residueStat;
        }
        if(rewardDate+ctx.least>=ctx.soleMax){
            ctx.WeightAndRewarddate[AttributeType]=0;
        }
        return rewardDate;
    }

    function getRandNumber(uint256 randDate,uint256 scope)
        private 
        pure 
        returns(uint256 rt)
    {
        if(scope==0){
            scope = 1;
        }
        rt = randDate%scope;
    }

    function weightNmb(uint seed,uint[] memory weight, uint weightSum)
        private 
        view  
        returns (uint ,uint)
    {
        uint new_seed = rand(seed);
        uint n = new_seed % weightSum + 1;
        uint sum = 0;
        for (uint i = 0; i < weight.length; i++) {
            sum += weight[i];
            if (n <= sum) {
                return (i, new_seed);
            }
        }

        revert("weightNum failed");
    }

    function getSoleAttributeDate(uint256 date,uint256 number) 
        private 
        pure 
        returns (string memory _uintAsString)
    {
        string memory intactdate = _uint2str(date);
        uint256 shortNumber = number - bytes(intactdate).length ;
        string memory shortDate="";
        string memory placeholder="0";
        for (uint256 i=0;i<shortNumber;i++){
            shortDate=_stringJoin(shortDate,placeholder);
        }
        return _stringJoin(shortDate,intactdate);
    }

    function _stringJoin(string memory _a, string memory _b) 
        private 
        pure 
        returns (string memory)
    {
        return string(abi.encodePacked(_a, _b));
   }

    function _uint2str(uint _i)
        private 
        pure 
        returns (string memory _uintAsString)
    {
        return Strings.toString(_i);
    }
}