import * as React from 'react';
import { compose, withState, withHandlers } from 'recompose';

import { Trans } from '@lingui/macro';
import { Grid, Row, Col } from '@zendeskgarden/react-grid';
import { RouteComponentProps } from 'react-router';
import { graphql, GraphqlQueryControls, OperationOption } from 'react-apollo';
import styled from '../../themes/styled';
import Main from '../../components/chrome/Main/Main';
import Community from '../../types/Community';
import Loader from '../../components/elements/Loader/Loader';
import { Tabs, TabPanel } from '../../components/chrome/Tabs/Tabs';
import Breadcrumb from './breadcrumb';
// import { CollectionCard } from '../../components/elements/Card/Card';
import CollectionCard from '../../components/elements/Collection/Collection';
import P from '../../components/typography/P/P';
import H2 from '../../components/typography/H2/H2';
// import H4 from '../../components/typography/H4/H4';
import Button from '../../components/elements/Button/Button';
import Discussion from '../../components/chrome/Discussion/Discussion';
import CommunityModal from '../../components/elements/CommunityModal';
import EditCommunityModal from '../../components/elements/EditCommunityModal';
import Join from '../../components/elements/Community/Join';
const { getCommunityQuery } = require('../../graphql/getCommunity.graphql');

enum TabsEnum {
  // Members = 'Members',
  Collections = 'Collections',
  Discussion = 'Discussion'
}

interface Data extends GraphqlQueryControls {
  community: Community;
}

type State = {
  tab: TabsEnum;
};

interface Props
  extends RouteComponentProps<{
      community: string;
    }> {
  data: Data;
  handleNewCollection: any;
  isOpen: boolean;
  editCommunity(): boolean;
  isEditCommunityOpen: boolean;
}

class CommunitiesFeatured extends React.Component<Props, State> {
  state = {
    tab: TabsEnum.Collections
  };

  render() {
    let collections;
    let community;
    if (this.props.data.error) {
      collections = (
        <span>
          <Trans>Error loading collections</Trans>
        </span>
      );
    } else if (this.props.data.loading) {
      collections = <Loader />;
    } else if (this.props.data.community) {
      community = this.props.data.community;
      if (this.props.data.community.collections.length) {
        collections = (
          <Wrapper>
            <CollectionList>
              {this.props.data.community.collections.map((collection, i) => (
                <CollectionCard
                  communityId={this.props.data.community.localId}
                  key={i}
                  collection={collection}
                />
              ))}
            </CollectionList>
            {community.followed ? (
              <WrapperActions>
                <Button onClick={this.props.handleNewCollection}>
                  <Trans>Create a new collection</Trans>
                </Button>
              </WrapperActions>
            ) : (
              <Trans>Join the community to create a collection</Trans>
            )}
          </Wrapper>
        );
      } else {
        collections = (
          <OverviewCollection>
            <P>
              <Trans>This community has no collections.</Trans>
            </P>
            {community.followed ? (
              <Button onClick={this.props.handleNewCollection}>
                <Trans>Create the first collection</Trans>
              </Button>
            ) : (
              <Trans>Join the community to create a collection</Trans>
            )}
          </OverviewCollection>
        );
      }
    }

    if (!community) {
      return <Loader />;
    }
    return (
      <>
        <Main>
          <Grid>
            <WrapperCont>
              <Breadcrumb name={community.name} />
              <Row>
                <Hero>
                  <Background
                    style={{ backgroundImage: `url(${community.icon})` }}
                  />
                  <HeroInfo>
                    <H2>{community.name}</H2>
                    <P>{community.summary}</P>
                    <Join
                      id={community.localId}
                      followed={community.followed}
                      externalId={community.id}
                    />
                  </HeroInfo>
                </Hero>
              </Row>
              <Row>
                <Col size={12}>
                  <WrapperTab>
                    <OverlayTab>
                      <Tabs
                        selectedKey={this.state.tab}
                        onChange={tab => this.setState({ tab })}
                        button={
                          community.localId === 7 ||
                          community.localId === 15 ? null : (
                            <Button
                              onClick={this.props.editCommunity}
                              secondary
                            >
                              <Trans>Edit</Trans>
                            </Button>
                          )
                        }
                      >
                        {/* <TabPanel
                        label={`${TabsEnum.Members} (${
                          community.followersCount
                        })`}
                        key={TabsEnum.Members}
                      >
                        <Members>
                          {community.followers.map((user, i) => (
                            <Follower key={i}>
                              <Img
                                style={{ backgroundImage: `url(${user.icon})` }}
                              />
                              <FollowerName>{user.name}</FollowerName>
                            </Follower>
                          ))}
                        </Members>
                      </TabPanel> */}
                        <TabPanel
                          label={`${TabsEnum.Collections}`}
                          key={TabsEnum.Collections}
                        >
                          <div style={{ display: 'flex', marginTop: '-20px' }}>
                            {collections}
                          </div>
                        </TabPanel>
                        <TabPanel
                          label={`${TabsEnum.Discussion}`}
                          key={TabsEnum.Discussion}
                        >
                          {community.followed ? (
                            <Discussion
                              localId={community.localId}
                              id={community.id}
                            />
                          ) : (
                            <Trans>Join the community to discuss</Trans>
                          )}
                        </TabPanel>
                      </Tabs>
                    </OverlayTab>
                  </WrapperTab>
                </Col>
              </Row>
            </WrapperCont>
          </Grid>
          <CommunityModal
            toggleModal={this.props.handleNewCollection}
            modalIsOpen={this.props.isOpen}
            communityId={community.localId}
            communityExternalId={community.id}
          />
          <EditCommunityModal
            toggleModal={this.props.editCommunity}
            modalIsOpen={this.props.isEditCommunityOpen}
            communityId={community.localId}
            communityExternalId={community.id}
            community={community}
          />
        </Main>
      </>
    );
  }
}

// const Members = styled.div`
//   display: grid;
//   grid-template-columns: 1fr 1fr 1fr 1fr;
//   grid-column-gap: 8px;
//   grid-row-gap: 8px;
// `;
// const Follower = styled.div``;
// const Img = styled.div`
//   width: 40px;
//   height: 40px;
//   border-radius: 100px;
//   margin: 0 auto;
//   display: block;
// `;
// const FollowerName = styled(H4)`
//   margin-top: 8px;
//   text-align: center;
// `;

const WrapperTab = styled.div``;
const OverlayTab = styled.div`
  background: #fff;
`;

const WrapperCont = styled.div`
  max-width: 1040px;
  margin: 0 auto;
  width: 100%;
  background: white;
`;

const WrapperActions = styled.div`
  margin: 8px;
`;

const Wrapper = styled.div`
  flex: 1;
`;

const CollectionList = styled.div`
  flex: 1;
`;

const OverviewCollection = styled.div`
  padding: 0 8px;
  margin-bottom: 8px;
  & p {
    margin-top: 0 !important;
  }
`;

const Hero = styled.div`
  margin-top: 16px;
  margin-bottom: 16px;
  width: 100%;
`;

const Background = styled.div`
  margin-top: 24px;
  height: 120px;
  width: 120px;
  border-radius: 4px;
  background-size: cover;
  background-repeat: no-repeat;
  background-color: #e6e6e6;
  position: relative;
  margin: 0 auto;
`;

const HeroInfo = styled.div`
  text-align: center;
  & h2 {
    margin: 0;
    font-size: 24px !important;
    line-height: 32px !important;
  }
  & p {
    color: rgba(0, 0, 0, 0.7);
    padding: 0 24px;
    font-size: 15px;
  }
  & button {
    span {
      vertical-align: sub;
      display: inline-block;
      height: 30px;
      margin-right: 4px;
    }
  }
`;

const withGetCollections = graphql<
  {},
  {
    data: {
      community: Community;
    };
  }
>(getCommunityQuery, {
  options: (props: Props) => ({
    variables: {
      context: parseInt(props.match.params.community)
    }
  })
}) as OperationOption<{}, {}>;

export default compose(
  withGetCollections,
  withState('isOpen', 'onOpen', false),
  withState('isEditCommunityOpen', 'onEditCommunityOpen', false),
  withHandlers({
    handleNewCollection: props => () => props.onOpen(!props.isOpen),
    editCommunity: props => () =>
      props.onEditCommunityOpen(!props.isEditCommunityOpen)
  })
)(CommunitiesFeatured);
