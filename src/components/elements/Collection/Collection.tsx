import * as React from 'react';
import styled from '../../../themes/styled';
import Collection from '../../../types/Collection';
import H5 from '../../typography/H5/H5';
import P from '../../typography/P/P';
import { Link } from 'react-router-dom';
import Join from './Join';
import { Resource, Eye } from '../Icons';

interface CollectionProps {
  collection: Collection;
  communityId: string;
}

const Collection: React.SFC<CollectionProps> = ({
  collection,
  communityId
}) => {
  return (
    <Wrapper>
      <Link
        to={`/communities/${communityId}/collections/${collection.localId}`}
      >
        <Img style={{ backgroundImage: `url(${collection.icon})` }} />
        <Infos>
          <Title>
            {collection.name.length > 80
              ? collection.name.replace(/^(.{76}[^\s]*).*/, '$1...')
              : collection.name}
          </Title>
          <Desc>
            {collection.summary.length > 320
              ? collection.summary.replace(
                  /^([\s\S]{316}[^\s]*)[\s\S]*/,
                  '$1...'
                )
              : collection.summary}
          </Desc>
          <Actions>
            <ActionItem>
              {collection.resources.totalCount || 0}{' '}
              <Resource
                width={18}
                height={18}
                strokeWidth={2}
                color={'#8b98a2'}
              />
            </ActionItem>
            <ActionItem>
              {collection.followersCount || 0}{' '}
              <Eye width={18} height={18} strokeWidth={2} color={'#8b98a2'} />
            </ActionItem>
          </Actions>
        </Infos>
      </Link>
      <Right>
        <Join
          followed={collection.followed}
          id={collection.localId}
          externalId={collection.id}
        />
      </Right>
    </Wrapper>
  );
};

const Right = styled.div`
  width: 160px;
`;

const Actions = styled.div`
  margin-top: 10px;
`;
const ActionItem = styled.div`
  display: inline-block;
  font-size: 14px;
  font-weight: 600;
  color: #8b98a2;
  text-transform: uppercase;
  margin-right: 20px;
  & svg {
    vertical-align: sub;
  }
`;

const Wrapper = styled.div`
  display: flex;
  border-bottom: 1px solid #ebe8e8;
  padding: 15px 10px;
  cursor: pointer;
  & a {
    display: flex;
    color: inherit;
    text-decoration: none;
    width: 100%;
  }
  &:hover {
    background: rgba(241, 246, 249, 0.65);
  }
`;
const Img = styled.div`
  width: 120px;
  height: 120px;
  border-radius: 2px;
  background-size: cover;
  background-repeat: no-repeat;
  background-color: #f0f0f0;
  margin-right: 10px;
`;
const Infos = styled.div`
  flex: 1;
`;
const Title = styled(H5)`
  font-size: 18px !important;
  margin: 0 0 8px 0 !important;
  line-height: 20px !important;
  letter-spacing: 0.8px;
`;
const Desc = styled(P)`
  margin: 0 !important;
  font-size: 14px !important;
`;

export default Collection;
