// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PriceFormula {
    using SafeMath for uint256;

    function getSumFixedPoint(
        uint256 x,
        uint256 y,
        uint256 A
    ) public pure returns (uint256) {
        if (x == 0 && y == 0) return 0;

        uint256 sum = x.add(y);

        for (uint256 i = 0; i < 255; i++) {
            uint256 dP = sum;
            dP = dP.mul(sum) / (x.mul(2)).add(1);
            dP = dP.mul(sum) / (y.mul(2)).add(1);

            uint256 prevSum = sum;

            uint256 n = (A.mul(2).mul(x.add(y)).add(dP.mul(2))).mul(sum);
            uint256 d = (A.mul(2).sub(1).mul(sum));
            sum = n / d.add(dP.mul(3));

            if (sum <= prevSum.add(1) && prevSum <= sum.add(1)) break;
        }

        return sum;
    }

    function getReturn(
        uint256 xQty,
        uint256 xBalance,
        uint256 yBalance,
        uint256 A
    ) public pure returns (uint256) {
        uint256 sum = getSumFixedPoint(xBalance, yBalance, A);

        uint256 c = sum.mul(sum) / (xQty.add(xBalance)).mul(2);
        c = c.mul(sum) / A.mul(4);
        uint256 b = (xQty.add(xBalance)).add(sum / A.mul(2));
        uint256 yPrev = 0;
        uint256 y = sum;

        for (uint256 i = 0; i < 255; i++) {
            yPrev = y;
            uint256 n = (y.mul(y)).add(c);
            uint256 d = y.mul(2).add(b).sub(sum);
            y = n / d;

            if (y <= yPrev.add(1) && yPrev <= y.add(1)) break;
        }

        return yBalance.sub(y).sub(1);
    }
}
