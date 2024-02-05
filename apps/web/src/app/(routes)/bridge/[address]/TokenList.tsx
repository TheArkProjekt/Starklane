/* eslint-disable @typescript-eslint/no-misused-promises */
"use client";

import { Button, Typography } from "design-system";
import Link from "next/link";

import InfiniteScrollButton from "~/app/_components/InfiniteScrollButton";
import NftCard from "~/app/_components/NftCard/NftCard";
import useCurrentChain from "~/app/_hooks/useCurrentChain";
import useInfiniteEthereumNfts from "~/app/_hooks/useInfiniteEthereumNfts";
import useInfiniteStarknetNfts from "~/app/_hooks/useInfiniteStarknetNfts";

import useNftSelection, { MAX_SELECTED_ITEMS } from "../_hooks/useNftSelection";

interface TokenListProps {
  nftContractAddress: string;
}

export default function TokenList({ nftContractAddress }: TokenListProps) {
  const { sourceChain } = useCurrentChain();

  const {
    deselectAllNfts,
    isNftSelected,
    selectBatchNfts,
    selectedCollectionAddress,
    toggleNftSelection,
    totalSelectedNfts,
  } = useNftSelection();

  const {
    data: l1NftsData,
    fetchNextPage: fetchNextl1NftsPage,
    hasNextPage: hasNextl1NftsPage,
    isFetchingNextPage: isFetchingNextl1NftsPage,
    totalCount: l1NftsTotalCount,
  } = useInfiniteEthereumNfts({ contractAddress: nftContractAddress });

  const {
    data: l2NftsData,
    fetchNextPage: fetchNextl2NftsPage,
    hasNextPage: hasNextl2NftsPage,
    isFetchingNextPage: isFetchingNextl2NftsPage,
    totalCount: l2NftsTotalCount,
  } = useInfiniteStarknetNfts({ contractAddress: nftContractAddress });

  // TODO @YohanTz: Extract to a hook
  const data = sourceChain === "Ethereum" ? l1NftsData : l2NftsData;
  const fetchNextPage =
    sourceChain === "Ethereum" ? fetchNextl1NftsPage : fetchNextl2NftsPage;
  const hasNextPage =
    sourceChain === "Ethereum" ? hasNextl1NftsPage : hasNextl2NftsPage;
  const isFetchingNextPage =
    sourceChain === "Ethereum"
      ? isFetchingNextl1NftsPage
      : isFetchingNextl2NftsPage;
  const totalCount =
    sourceChain === "Ethereum" ? l1NftsTotalCount : l2NftsTotalCount;

  if (data === undefined) {
    return;
  }

  const hasMoreThan100Nfts =
    data.pages.length > 1 || (data.pages.length === 1 && hasNextPage);

  const isAllSelected =
    (totalSelectedNfts === MAX_SELECTED_ITEMS ||
      totalSelectedNfts === data.pages[0]?.ownedNfts.length) &&
    nftContractAddress === selectedCollectionAddress;

  return (
    <div className="mb-4 flex flex-col items-start">
      {/* TODO @YohanTz: Refacto to be a variant in the Button component */}
      <Link
        className="mb-10 inline-flex h-12 items-center gap-1.5 rounded-full border-2 border-asteroid-grey-600 px-6 py-3 text-asteroid-grey-600 dark:border-space-blue-300 dark:text-space-blue-300"
        href="/bridge"
      >
        {/* TODO @YohanTz: Export svg to icons file */}
        <svg
          fill="none"
          height="24"
          viewBox="0 0 24 24"
          width="24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M20.25 12L12.7297 12C11.9013 12 11.2297 12.6716 11.2297 13.5L11.2297 16.4369C11.2297 17.0662 10.5013 17.4157 10.0104 17.0219L4.47931 12.585C4.10504 12.2848 4.10504 11.7152 4.47931 11.415L10.0104 6.97808C10.5013 6.58428 11.2297 6.93377 11.2297 7.56311L11.2297 9.375"
            stroke="currentColor"
            strokeLinecap="round"
            strokeWidth="1.5"
          />
        </svg>
        <Typography variant="button_text_s">Back</Typography>
      </Link>
      <div className="mb-10 flex w-full flex-wrap justify-between gap-3.5">
        <div className="flex max-w-full items-center gap-3.5">
          <Typography ellipsable variant="heading_light_s">
            {/* {data.pages[0]?.ownedNfts[0]?.contract.name ??
              data.pages[0]?.ownedNfts[0]?.contract.symbol}{" "} */}
            Collection
          </Typography>
          <Typography
            className="shrink-0 rounded-full bg-primary-source px-2 py-1.5 text-white"
            variant="body_text_12"
          >
            {totalCount}
            {totalCount > 1 ? " Nfts" : " Nft"}
          </Typography>
        </div>
        {isAllSelected ? (
          <Button color="default" onClick={deselectAllNfts} size="small">
            Deselect All
          </Button>
        ) : (
          <Button
            onClick={() => {
              selectBatchNfts(data.pages[0]?.ownedNfts ?? []);
            }}
            color="default"
            size="small"
          >
            <Typography variant="button_text_s">
              {hasMoreThan100Nfts ? "Select 100 Max" : "Select All"}
            </Typography>
          </Button>
        )}
      </div>

      <div className="grid w-full grid-cols-2 gap-5 sm:grid-cols-3 lg:grid-cols-5">
        {data.pages.map((page) => {
          return page.ownedNfts.map((ownedNft) => {
            const isSelected = isNftSelected(
              ownedNft.tokenId,
              ownedNft.contractAddress
            );

            return (
              <NftCard
                onClick={() =>
                  toggleNftSelection(ownedNft.tokenId, ownedNft.contractAddress)
                }
                cardType="nft"
                chain={sourceChain}
                image={ownedNft.image}
                isSelected={isSelected}
                key={ownedNft.tokenId}
                title={ownedNft.name}
              />
            );
          });
        })}
      </div>
      <InfiniteScrollButton
        className="mx-auto mt-14"
        fetchNextPage={() => fetchNextPage()}
        hasNextPage={hasNextPage}
        isFetchingNextPage={isFetchingNextPage}
      />
    </div>
  );
}
