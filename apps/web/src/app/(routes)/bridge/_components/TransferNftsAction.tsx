import clsx from "clsx";
import { Button, Typography } from "design-system";

import useCurrentChain from "~/app/_hooks/useCurrentChain";

import useNftSelection from "../_hooks/useNftSelection";
import useTransferNftsFromChain from "../_hooks/useTransferNfts";

export default function TransferNftsAction() {
  const { sourceChain, targetChain } = useCurrentChain();
  const { totalSelectedNfts } = useNftSelection();

  const { approveForAll, depositTokens, isApproveLoading, isApprovedForAll } =
    useTransferNftsFromChain(sourceChain);

  return isApprovedForAll ? (
    <Button
      className="mt-8 bg-galaxy-blue text-white dark:bg-primary-400 dark:text-galaxy-blue"
      onClick={() => depositTokens()}
      size="small"
    >
      <Typography variant="button_text_s">
        Confirm transfer to {targetChain}
      </Typography>
    </Button>
  ) : (
    <>
      {totalSelectedNfts > 0 && isApprovedForAll !== undefined && (
        <Typography
          className="mt-8 flex gap-2.5 rounded-xl bg-playground-purple-100 p-3 text-playground-purple-800 dark:bg-playground-purple-400 dark:text-space-blue-900"
          component="p"
          variant="body_text_14"
        >
          <svg
            className="flex-shrink-0"
            fill="none"
            height="32"
            viewBox="0 0 32 32"
            width="32"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M30.555 13.0686C30.7391 18.8906 26.2996 25.363 18.8398 26.5409C14.1036 27.2888 10.0434 25.9494 7.11476 23.7515C4.1716 21.5427 2.40664 18.497 2.20463 15.8707C2.00595 13.2876 3.3401 10.8487 5.91453 8.95722C8.4917 7.06374 12.2804 5.75054 16.8548 5.46463C21.4456 5.1777 24.7793 5.87994 27.0008 7.24017C29.1963 8.58448 30.349 10.5966 30.555 13.0686Z"
              fill="#7D56E5"
              stroke="#0E2230"
            />
            <path
              d="M25.8054 14.2174C25.6899 12.2929 24.0361 10.8264 22.1116 10.942C20.1871 11.0575 18.7206 12.7112 18.8361 14.6358"
              stroke="#0E2230"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            <path
              d="M14.6758 15.4133C14.1347 13.5628 12.196 12.5013 10.3455 13.0423C8.495 13.5834 7.43347 15.5221 7.9745 17.3726"
              stroke="#0E2230"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          You must approve the selection of your assets before confirming the
          migration. Each collection will require a signature via your wallet.
        </Typography>
      )}
      <Button
        className={clsx(
          "mt-8",
          totalSelectedNfts === 0
            ? "cursor-no-drop bg-asteroid-grey-300 text-white opacity-50 dark:bg-primary-source dark:text-galaxy-blue"
            : "bg-space-blue-900 text-white dark:bg-primary-source dark:text-galaxy-blue"
        )}
        // disabled={numberOfSelectedNfts === 0}
        onClick={() =>
          !isApproveLoading && totalSelectedNfts > 0 && approveForAll()
        }
        size="small"
      >
        <Typography variant="button_text_s">
          {isApproveLoading
            ? "Approve in progress..."
            : totalSelectedNfts === 0
            ? `Confirm transfer to ${targetChain}`
            : "Approve the selected Nfts"}
        </Typography>
      </Button>
    </>
  );
}