import { useAccount } from "wagmi";
import { api } from "~/utils/api";

import { useState } from "react";
import NftCard from "./NftCard";
import { IconButton } from "design-system";

interface TokenListProps {
  selectedNftIds: Array<string>;
  setSelectedNftIds: (nfts: Array<string>) => void;
}

// TODO @YohanTz: Take time to optimize the lists with React.memo etc.
export default function TokenList({
  selectedNftIds,
  setSelectedNftIds,
}: TokenListProps) {
  const [selectedCollectionName, setSelectedCollectionName] = useState<
    null | string
  >(null);
  const { address: ethereumAddress } = useAccount();

  const { data: nfts } = api.nfts.getL1NftsByCollection.useQuery(
    {
      address: ethereumAddress ?? "",
    },
    { enabled: ethereumAddress !== undefined }
  );

  function handleNftClick(nftId: string) {
    if (selectedNftIds.includes(nftId)) {
      setSelectedNftIds(
        selectedNftIds.filter((selectedNftId) => selectedNftId !== nftId)
      );
      return;
    }
    setSelectedNftIds([...selectedNftIds, nftId]);
  }

  function handleCollectionClick(collectionName: string) {
    setSelectedCollectionName(collectionName);
  }

  function selectAll() {
    if (nfts === undefined) {
      return;
    }
    setSelectedNftIds(
      nfts.byCollection[selectedCollectionName].map((nft) => nft.id)
    );
  }

  if (nfts === undefined) {
    return null;
  }

  const selectedCollection = selectedCollectionName
    ? nfts.byCollection[selectedCollectionName] ?? []
    : [];

  return (
    <>
      {/* TODO @YohanTz: Export Tabs logic to design system package ? */}
      <div className="w-full">
        <div className="mb-10 flex w-full justify-between">
          <div className="flex items-center gap-3.5">
            <span className="text-2xl font-bold">
              {selectedCollectionName ?? "Your collections"}
            </span>
            {selectedCollectionName !== null && (
              <span className="rounded-full bg-primary px-1.5 text-sm text-white">
                {selectedCollection.length}
                {selectedCollection.length > 1 ? " Nfts" : " Nft"}
              </span>
            )}
          </div>
          {selectedCollectionName !== null && (
            <button
              className="rounded-md bg-sky-950 px-3 py-1 font-medium text-white"
              onClick={selectAll}
            >
              Select all
            </button>
          )}
        </div>
        <div className="grid grid-cols-3 gap-5 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6">
          {selectedCollectionName === null
            ? Object.entries(nfts.byCollection).map(
                ([collectionName, nfts]) => {
                  const isSelected = nfts.every((nft) =>
                    selectedNftIds.includes(nft.id)
                  );

                  return (
                    <NftCard
                      isSelected={isSelected}
                      cardType="collection"
                      image={nfts[0]?.image}
                      key={collectionName}
                      numberOfNfts={nfts.length}
                      onClick={() => handleCollectionClick(collectionName)}
                      title={collectionName}
                    />
                  );
                }
              )
            : selectedCollection.map((nft) => {
                const isSelected = selectedNftIds.includes(nft.id);

                return (
                  <NftCard
                    cardType="nft"
                    image={nft.image}
                    isSelected={isSelected}
                    key={nft.id}
                    onClick={() => handleNftClick(nft.id)}
                    title={nft.title}
                  />
                );
              })}
        </div>
      </div>
    </>
  );
}