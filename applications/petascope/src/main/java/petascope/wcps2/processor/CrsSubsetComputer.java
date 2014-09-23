package petascope.wcps2.processor;

import petascope.wcps2.metadata.Coverage;
import petascope.wcps2.metadata.CoverageRegistry;
import petascope.wcps2.metadata.Interval;
import petascope.wcps2.translator.*;
import petascope.wcps2.util.CrsComputer;

/**
 * Calculates the pixel array bounds based on the subset given taking the crs of the coverage expression into account
 *
 * @author <a href="mailto:alex@flanche.net">Alex Dumitru</a>
 * @author <a href="mailto:vlad@flanche.net">Vlad Merticariu</a>
 */
public class CrsSubsetComputer implements IProcessor {

    @Override
    public void process(IParseTreeNode translationTree, IParseTreeNode currentNode, CoverageRegistry coverageRegistry) {
        if (currentNode instanceof TrimExpression) {
            processTrimExpression(currentNode, coverageRegistry);
        } else if (currentNode instanceof ExtendExpression) {
            processExtendExpression(currentNode);
        } else if (currentNode instanceof ScaleExpression) {
            processScaleExpression(currentNode, coverageRegistry);
        }
    }

    @Override
    public boolean canProcess(IParseTreeNode currentNode) {
        if (currentNode instanceof TrimExpression
            || currentNode instanceof ExtendExpression
            || currentNode instanceof ScaleExpression) {
            return true;
        }
        return false;
    }

    /**
     * Processes a trim expression calculating the pixel bounds
     *
     * @param currentNode      the current node where the trim was detected
     * @param coverageRegistry the coverage registry
     */
    private void processTrimExpression(IParseTreeNode currentNode, CoverageRegistry coverageRegistry) {
        TrimExpression trim = (TrimExpression) currentNode;
        Coverage coverage = trim.getCoverageExpression().getCoverage();
        for (TrimDimensionInterval trimInterval : trim.getDimensionIntervalList().getIntervals()) {
            String crs = trimInterval.getCrs();
            if (coverage.getCoverageInfo().getCoverageCrs() == null) {
                crs = coverage.getCoverageInfo().getCoverageCrs();
            }
            CrsComputer crsComputer = new CrsComputer(trimInterval.getAxisName(), crs, trimInterval.getRawTrimInterval(), coverage, coverageRegistry);
            Interval<Long> pixelIndices = crsComputer.getPixelIndices();
            trimInterval.setTrimInterval(pixelIndices);
        }
    }


    /**
     * Processes a scale expression calculating the pixel bounds
     *
     * @param currentNode      the current node where the trim was detected
     * @param coverageRegistry the coverage registry
     */
    private void processScaleExpression(IParseTreeNode currentNode, CoverageRegistry coverageRegistry) {
        ScaleExpression scale = (ScaleExpression) currentNode;
        Coverage coverage = scale.getCoverage();
        for (TrimDimensionInterval trimInterval : scale.getDimensionIntervals().getIntervals()) {
            String crs = trimInterval.getCrs();
            if (coverage.getCoverageInfo().getCoverageCrs() == null) {
                crs = coverage.getCoverageInfo().getCoverageCrs();
            }
            CrsComputer crsComputer = new CrsComputer(trimInterval.getAxisName(), crs, trimInterval.getRawTrimInterval(), coverage, coverageRegistry);
            Interval<Long> pixelIndices = crsComputer.getPixelIndices();
            trimInterval.setTrimInterval(pixelIndices);
        }
    }

    /**
     * Processes an extend expression calculating the pixel bounds
     *
     * @param currentNode the node where the extend expression was found
     */
    private void processExtendExpression(IParseTreeNode currentNode) {
        ExtendExpression trim = (ExtendExpression) currentNode;
        for (TrimDimensionInterval trimInterval : trim.getDimensionIntervalList().getIntervals()) {
            Interval<Long> pixelIndices = new Interval<Long>(Long.valueOf(trimInterval.getRawTrimInterval().getLowerLimit()), Long.valueOf(trimInterval.getRawTrimInterval().getUpperLimit()));
            trimInterval.setTrimInterval(pixelIndices);
        }
    }
}